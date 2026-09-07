# Tunneling, swimming and climbing — connected design review

Document `SET-TRAVERSAL-REVIEW-001`, revision 1.1, 2026-09-06. Sources: IMG-08/09/10/11, supporting IMG-03/04/06/07/17/18/19/20/23/25/27, and the existing project specifications. Status: **direction adopted by DEC-035**, with [SET-MOVE-001](../movement_direction_amendment.md) now the normative owner. Detailed mechanisms and synthetic numeric fixtures here remain engineering proposals until their owner gates close; this is not a complete production subsystem or new active ruleset.

## 1. Recommendation

Make the woodland a connected place with ground, inhabited underground space, water and canopy routes. Different bodies and equipment should make those routes feel different. Use the same authoritative spatial relationships for settlement work and traversal, while keeping settlement and battle stores separate. A tunnel should remain a real passage after its builders leave; a swimmer should enter and leave at a real bank; a climber should follow connected surfaces rather than float above the ground.

The immediate value extends beyond battle: accessible homes, underground stores, river livelihoods, orchard work, elevated lookout places and credible daily movement. Tactical tunneling, counter-sapping, submerged attacks and canopy ambushes can build on those spaces later. They do not have to define the ordinary colony's tone.

| Scope | Present authority | Required consequence |
|---|---|---|
| Burrow placement, planned tunnels/rooms and free multi-level excavation | DEC-029/031: user-confirmed, required first-release scope | Finish one interoperable construction/spatial specification; do not downgrade to decorative entrances or one level |
| Swimming/diving | DEC-035 user-confirmed direction; SET-MOVE-001 supersedes the release-wide water exclusion | Required surface/diving/shore behavior; complete production profiles under MOVE-G01 |
| Climbing/canopy travel | DEC-035 user-confirmed connected access; anatomy alone still grants no bypass | Required ordinary access/work and return; specify profiles, surfaces and contacts |
| Sapping, traps, water combat, flying counters | Source-slide proposals; current settlement has no combat | Keep in the battle/campaign design branch of this review |
| Inhabited multi-level navigation | Already necessary for DEC-029/031 | Update flat-world capacities, routes, services, editing and saves together |

No photographed turn count becomes a fixed-tick duration. No source species list is an adopted ability table. Movement capability describes a body/training/equipment profile, never moral worth or automatic colony admission.

## 2. What the slides actually propose

| Source | Explicit proposal | Useful transfer | Qualification |
|---|---|---|---|
| IMG-08 | Moles, rats and hedgehogs tunnel slowly past surface obstacles | Digging specialism and persistent alternative access | Traveling through a passage differs from creating it |
| IMG-08 | Deeper routes can pass below water but risk disaster | Depth and water relationship must be modeled | No depth limit, flooding model or chance is supplied |
| IMG-08 | Sappers sense digging, block tunnels and set traps | Detectable work and counter-access tools | Does not imply omniscient enemy location or current settlement warfare |
| IMG-08 | Attached specialists grant tunneling/speed/stealth | Skilled guidance can enable a group plan | Group eligibility still requires physical clearance, work and access |
| IMG-09 | Arboreal units move through canopy at full speed | Connected elevated routes | Full speed is a proposal, not measured anatomy or an inherited speed value |
| IMG-09 | Forest hiding persists aloft; ambush trait defeats ground spotting | Canopy visibility deserves independent rules | Avoid unconditional invisibility without an explicit counter/information contract |
| IMG-10 | Amphibious and aquatic-only units; fords and water chokepoints | Separate domain eligibility and transitions | No water-only ground fallback |
| IMG-10 | Breath-limited diving | Planned submerged segments with a return-to-air budget | Oxygen demand is gameplay design, not a medical/physiology claim |
| IMG-10 | Sling/javelin use while swimming with lower range | Weapon-specific surface work/combat modes | Surface use and underwater use are distinct |
| IMG-11 | Flyers threaten canopy and some swimmers | Cross-domain interaction | Seeing, reaching and attacking remain separate queries |
| IMG-11 | Mud/sand and fatigue affect heavy units strongly | Mode/load-specific terrain costs | Do not infer costs from rendered texture or copy an unstated multiplier |

## 3. Shared spatial vocabulary

Proposed conceptual graph:

```text
 CANOPY:    [work platform]---branch---[junction]---branch---[lookout]
                  | trunk/ladder                         | descent
                  |                                      |
 GROUND:       [landing]-------[hall / paths]----------[bank]
                                  | stair/ramp             | entry/exit
                                  |                       |
 UNDERGROUND: [room]---[finished tunnel]---[work face]    [surface water]
                          | vertical access                 | dive/ascend
                       [deeper room]                    [submerged route]
```

The diagram is an original topology explanation, not an approved map or coordinate layout. The water route is not automatically connected to the tunnel beneath it. A tree branch at the same horizontal coordinate as a room is still a different place.

Use proposed `space_kind` labels `GROUND`, `INTERIOR`, `UNDERGROUND`, `CANOPY`, `WATER_SURFACE`, `WATER_SUBMERGED`. They are documentation symbols, not numeric assignments to the battle catalog's existing GROUND=0/AIR_LOW=1/WATER=2. Vertical level is a separate signed field; it is not inferred from `space_kind` or visual Y alone.

**Important adaptation:** a bird flight space would be another explicitly designed domain. Adding canopy movement does not silently provide free flight. A ladder is a transition type, not a species trait. A burrow door is an access portal, not a teleport to a separate unrelated save.

## 4. Data-oriented contract to carry into the owning amendment

The following fields identify required state ownership. They do not replace existing registry columns or establish arena capacities. Use packed columns, versioned handles and immutable catalogs; no per-resident movement Node or component object.

| Table / owner | Required information | Why it matters |
|---|---|---|
| Spatial location catalog | Stable location ID, space kind, level, integer position, occupancy/clearance class, topology revision | Same X/Z cannot identify two vertically separated residents |
| Directed connection catalog | Stable edge ID, endpoints, transition kind, required capability bits, width/height, load limit, travel-cost profile, active revision | A route is a sequence of legal interfaces, not just nearby points |
| Movement profile catalog | Capability bits, posture envelope, allowed equipment/cargo profiles, speed/cost profile by mode | Anatomy alone does not decide eligibility |
| Resident traversal columns | Current location/mode, route handle+generation, active edge, progress, held reservation, capability-profile revision, underwater-budget state if used | Traversal survives save/load and equipment changes |
| Shared reservation arena | Edge/resource handle, resident handle, request order, direction, entry tick, release state | Narrow passages need deterministic occupancy and fair waiting |
| Construction / topology transaction | Affected cells/edges, work/material/spoil commitments, active users, publication revision | Excavation and access removal must be atomic |
| Presentation snapshot | Committed mode/pose intent, prior/current root, contact anchors, selected-layer information | Animation depicts committed movement without deciding it |

An edge with no load restriction uses an explicit catalog flag, not a zero accidentally interpreted as both unlimited and impassable. No route uses an undeclared domain. Carrying someone, towing an object or boarding a boat is a separate profile/action contract; do not add them through an implicit special case.

### 4.1 Eligibility and travel cost

For resident profile `p` and connection `e`, the candidate eligibility predicate is:

```text
eligible(p,e) =
    e.active
    AND valid(e.from) AND valid(e.to)
    AND ((p.capability_bits AND e.required_bits) == e.required_bits)
    AND p.width_units <= e.clear_width_units
    AND p.height_units <= e.clear_height_units
    AND (e.unlimited_load OR p.total_load_g <= e.load_limit_g)
    AND equipment_allowed(p,e)
    AND access_policy_allows(p,e)
```

`p` includes the occupied posture and carried kit: a folded lantern profile and a raised lantern profile can differ. A crouch option requires an actual eligible posture/animation and a defined transition; it is not automatic scaling. Access-policy eligibility, physical eligibility and job authorization are separate predicates. A child being physically small enough does not make a hazardous excavation job allowed.

For a finite, positive edge length `L` and positive speed `S` in simulation units per tick, use `ceil_div(L,S)` as the travel duration before explicitly declared entry/exit durations. For constant integer speed, advance `progress = min(L, progress + S)` each committed movement tick. With integer endpoints, a simple segment's root is `from + trunc_div((to-from)*progress,L)` independently per axis, using int64 intermediates. Curved movement requires an authored integer polyline with cumulative lengths and the same signed division convention. Zero-length transfers require a separate explicit duration/type, not division by zero.

These are proposed formulas. Production speed tables, posture envelopes, transition durations, load limits and finite arenas remain required inputs to the final amendment. The review does not claim that a formula without those catalogs is ready to implement.

### 4.2 Route search and cached answers

The existing octile heuristic assumes one flat ground graph with its 10/14 edge costs. It is not automatically admissible after adding shortcuts, different speeds or vertical connections. For the correctness reference implementation, use Dijkstra (`h=0`) with nonnegative integer tick costs and stable `(cost, location_id, mode_id)` ordering. An optimized hierarchy/heuristic must be proven against that reference on the same authored fixtures.

Proposed cache key includes exact destination location, start component/bucket, movement-profile revision, capability bits, cargo/equipment profile, access-policy revision and topology revision. Preserve the existing distinction between a macro bucket and proof that the actual start can reach its anchor. Reuse cannot cross disconnected floors, banks or sides of a wall. Dynamic reservations may change entry time; a cached topological route is not a guaranteed slot booking.

Store pending search/queue state and reserved-route identity in saves wherever they affect readiness. A worker result arriving earlier on Windows must not grant earlier access. The current 2048-expansion quota already fails some cold-burst latency fixtures; adding layers needs new measurement and an explicit performance amendment. Do not multiply the graph and retain the old latency claim by assertion.

## 5. Tunneling — TRV-T01 through TRV-T06

| ID | Required distinction / proposed handling | Model and world implications |
|---|---|---|
| TRV-T01 | Excavation turns solid material into an open, connected space only after committed work/material/spoil rules finish | Show working face, tool contact, unfinished terrain and spoil; no walking into a blueprint |
| TRV-T02 | Existing passages are traversable by every eligible resident/profile, independently of who dug them | Moles specialize in creation; other residents can inhabit the resulting home |
| TRV-T03 | Placed burrows, planned rooms and free excavation publish to the same topology/room/service identities | Shared doors, stairs, reservations, warmth/service reach and saved IDs |
| TRV-T04 | Underground walls/doors block specific connections; surface walls have foundations represented explicitly | No universal bypass beneath every wall and no visual wall that routes ignore |
| TRV-T05 | Depth/water/structure hazards remain a distinct design decision, with visible evidence and deterministic rules | Author soil/rock/water boundary and support representation before a collapse/flood system |
| TRV-T06 | Detecting digging reports bounded evidence of work; hostile route and trap systems belong to tactical design | Hearing a work sector need not reveal every underground enemy or room |

Recommended excavation order: validate planned region and accessible work face; reserve permitted inputs/worker access; perform work under the existing job scheduler; account for removed material and spoil using an explicit conservation rule; validate the resulting connectivity/support state; publish the topology change at a committed tick. Canceled projects keep already recorded work/material state under the owning construction rules; they do not leave an invisible traversable hole.

Occupied-space edits are transactional. A player-requested removal of the only valid access is refused while it would strand occupants or invalidate a necessary in-progress transfer. This is a safety rule for authorized editing, not a guarantee against every future disaster. Hazards that destroy an occupied route need separate deterministic injury, rescue and recovery rules before activation. No random “deeper means disaster” percentage is invented here.

A tunneling specialist can provide a trained builder, knowledge of an entrance, or a work-profile change. It cannot grant the entire party instant passage through untouched terrain. Counter-sapping and traps require visibility, friendly access, trigger identity, disarming, damage and save contracts. They are deliberately identified as incomplete tactical features rather than concealed in the room-building implementation.

## 6. Swimming and diving — TRV-W01 through TRV-W07

| ID | Proposed handling | Necessary state / presentation |
|---|---|---|
| TRV-W01 | Walking through the current shallow ford remains ground movement; surface swimming uses a separate eligible profile | Distinct contact height and clip; no automatic assignment from water color |
| TRV-W02 | Enter/exit only at validated bank connections whose approach and landing fit the body/load | Bank reach, handhold, slope/clearance and occupied landing reservation |
| TRV-W03 | Surface swimmers and aquatic-only creatures have different legal domains | A water-only fish cannot follow a failed water route across grass |
| TRV-W04 | Diving is a planned submerged segment between valid air-access points or an explicitly aquatic destination | Underwater budget, segment progress, reserved/reachable exit, submerged visibility |
| TRV-W05 | Surface work/fire requires its own supported hand/tool posture; underwater use is separately declared | Stowed incompatible gear; no standing-in-midwater pose |
| TRV-W06 | Aquatic harvesting draws from existing basin stock and effort/return accounting | No duplicated stock from different routes, zones or species |
| TRV-W07 | Rescue, towing, currents, floods and freezing are named follow-on decisions, not implied by swimming | Exact rules must exist before enabling those hazards/interactions |

Recommended dive planning uses prevalidated submerged macro-connections with a declared worst-case committed traversal duration and a valid surfacing destination. For non-aquatic profiles, permit entry only if `travel_budget + declared_contingency_budget <= available_underwater_budget`. All quantities are integer ticks in the proposed abstraction. Do not treat this as a physiological estimate.

A simple shortest path through underwater cells without tracking consumed budget is insufficient. For general underwater pathfinding, search must retain resource-feasible alternatives; for a bounded first design, authored submerged segments avoid that expanded search state. Either approach must handle a failed exit. The preferred ordinary-order policy is to reserve the exit resource before submerging and reject topology edits that remove it during the segment. An unavoidable hazard remains a separate contract.

While submerged, a non-aquatic profile consumes one budget tick per simulation tick, including waiting. Pausing consumes none. If a segment is interrupted while its validated retreat remains reachable, commit retreat using the remaining budget and display it. Do not reset the budget by switching a visual animation or crossing a water-cell boundary. Exact recovery at air, contingency budgets, exhaustion outcomes and any injury threshold are outstanding production choices. No lethal drowning mechanic is silently adopted.

The source's ranged-swimming reduction cannot become an arbitrary global multiplier. Each supported weapon must identify usable mode, hand occupancy, projectile origin, target domains and line-of-fire rules. A creature on a raft is a passenger on a platform, not a swimmer. A bow on a dry deck and a sling used while treading water require different actions.

## 7. Climbing and canopy travel — TRV-C01 through TRV-C07

| ID | Proposed handling | Required artifact |
|---|---|---|
| TRV-C01 | Distinguish a ladder, a climbable trunk/face and branch travel | Cataloged access method and contact anchors |
| TRV-C02 | Climbing starts and ends at stable, reserved landings | Enter/climb/hold/reverse/exit poses and valid endpoint placement |
| TRV-C03 | Canopy routes use authored connected branches, including junctions and descents | Branch ID/parent, width, clearance, load policy and topology revision |
| TRV-C04 | Cargo and equipment must fit both the route and the grip requirement | Available-hand/support profile and stowed kit |
| TRV-C05 | Cutting a tree or deleting a platform checks dependent routes, occupants and reservations | Transactional edit validation and intelligible refusal |
| TRV-C06 | Canopy visibility is independent from ground reach | Occlusion/observer relations and target-domain rules |
| TRV-C07 | Ordinary canopy work needs a safe return route; jumping/falling are separate mechanics | Work socket, route identity and interruption behavior |

Prefer authored branch centerlines and contact anchors over a promise to climb every procedurally placed triangle. Trees that are purely scenic are visually distinguishable or inspectably labeled; a climbable tree exposes its usable route. This remains compatible with multiple-level underground free excavation because it concerns canopy authoring, not a restriction on digging.

For the initial design, do not assume branch-to-branch jumping. A gap needs an explicitly supported connection type and landing. The image shows a squirrel supported by branches, not a proof of arbitrary ballistic traversal. Descending a ladder, reversing on a trunk and turning on a branch need different clearances; a route can be one-way if the corresponding reverse motion is not supported.

Forest concealment may apply at elevation, but an observer's detection must be an authored query. Being offscreen or behind a camera-cutaway tree does not change simulation visibility. “Unspottable to all ground troops” is an absolute trait proposal from the slide; our recommendation is to preserve counterplay and state it in the future combat visibility matrix before adoption.

## 8. Interaction and group rules

| Situation | Required distinction |
|---|---|
| Worker underground while another stands above | Different spatial identities; surface proximity alone cannot satisfy a handoff |
| Swimmer sees a climber | Visibility does not grant a usable attack or reachable work location |
| A flyer sees a submerged creature | Water occlusion/depth and attack capability must both be declared |
| Mixed party reaches a narrow tunnel | Route must fit every participating profile, or explicitly split into separately controlled groups |
| Specialist is detached mid-plan | Revalidate capability-dependent future segments; do not erase physical tunnel space already created |
| Resident changes load/gear | Revalidate before entering an incompatible edge; retain a valid held traversal profile while on an edge |
| Group routes beneath a river | Ground, underground and underwater connections remain separate; the tunnel does not become water merely because X/Z overlaps |

A battle formation cannot keep its open-field width inside a one-body passage. Specify queueing, regrouping and command acknowledgment at portals before tactical use. Never teleport trailing models to preserve a squad shape. Colony routes operate on residents/jobs; battle formation logic remains in the separate battle store.

## 9. UI and feedback concept

New UI behavior must extend the existing control registry. The following is an ASCII content layout, not a replacement for its pixel geometry, fonts or accessibility contract.

```text
+---------------- Route inspection ----------------+
| Selected: resident / job                         |
| Destination: named place, level, work position    |
| Route: Ground > Bank > Surface water > Bank       |
| State: Waiting for exit landing                  |
| Cargo: named load     Required hands: stated      |
| [Follow resident] [Inspect route] [Cancel order]  |
+-------------------------------------------------+
| View: Ground / Canopy / Water / Underground      |
| Underground level: previous | current | next      |
| Visible route: solid; other level: labeled marker |
+-------------------------------------------------+
```

Use truthful states: `Planning route`, `Waiting for access`, `Digging`, `Using tunnel`, `Climbing`, `Swimming`, `Diving`, `Returning to air`, `Blocked: no exit`, or `Blocked: load does not fit`, as appropriate to the actual committed state. Do not show `Swimming` merely because a resident is near water.

When viewing another level, preserve a discoverable selected-resident marker with its level and a follow action. Surface picking must not accidentally select the person below a floor unless that layer is active or the user selects it through the world list. Cutaway rendering never deletes collision, reveals undiscovered enemies or changes fog-of-war. Give icons/text as well as color to distinguish routes. Dangerous or invalid orders explain the reason before committing; an opaque red path alone is insufficient.

The source slides' parchment, circles and serif typography may inform codex presentation, but they do not override current operational UI readability. No new hotkey is assigned here; conflicts must be resolved in `ui_ux_controls.md`.

## 10. EARS requirements for the final feature specification

| ID | Requirement |
|---|---|
| TRV-REQ01 | WHEN a route changes spatial domain, the system shall validate and execute a declared connection with stable endpoints. |
| TRV-REQ02 | IF a body, posture, capability or load does not satisfy a connection, THEN route planning shall refuse that connection and report the failed condition. |
| TRV-REQ03 | WHILE excavation is incomplete, the system shall keep the unexcavated portion non-traversable. |
| TRV-REQ04 | WHEN any underground construction method completes a space, the system shall publish it through the same topology, room and service interfaces. |
| TRV-REQ05 | WHEN an occupied access connection is targeted for player removal, the system shall refuse the edit if it would strand an occupant or invalidate a held transition. |
| TRV-REQ06 | WHEN two residents request a one-at-a-time connection, the system shall select its owner by a documented stable queue order and preserve that order in saves. |
| TRV-REQ07 | IF a planned non-aquatic dive lacks a valid air endpoint or sufficient budget, THEN the system shall refuse entry before submerging the resident. |
| TRV-REQ08 | WHILE a non-aquatic resident is submerged, the system shall debit the committed underwater budget on simulation ticks, including waiting, and debit nothing while paused. |
| TRV-REQ09 | WHEN equipment or cargo changes route eligibility, the system shall invalidate incompatible future route segments at the committed profile revision. |
| TRV-REQ10 | WHEN harvesting is reached through a water route, the economy shall use the same authoritative habitat stock as all other harvesting of that basin. |
| TRV-REQ11 | WHEN a route is interrupted, the system shall publish its blocked/retreat state and preserve a valid occupied location rather than using a visual teleport fallback. |
| TRV-REQ12 | WHEN the camera hides a spatial layer, the renderer shall preserve the simulation's occupancy, discovery and visibility state. |
| TRV-REQ13 | WHEN a save resumes during traversal, the system shall restore progress, profile, reservations, search readiness and budget before advancing the next tick. |
| TRV-REQ14 | WHEN a group uses a constrained connection, the simulation shall account for each participating entity and its eligibility rather than granting passage from a specialist's presence alone. |
| TRV-REQ15 | WHILE reduced-detail rendering is active, models shall retain the correct movement family and domain even when contact detail is simplified. |

The adopted behavior is now normative in MOVE-REQ-001–020 under SET-MOVE-001. This review retains proposed engineering interfaces; incomplete production algorithms and synthetic numerical fixtures remain explicitly unqualified.

## 11. Concrete design-verification fixtures

All values in this section are **NEW synthetic test inputs**, not gameplay balance or extracted biological measurements. They let an implementation proposal demonstrate its semantics before tuning a real map.

| Fixture | Exact input | Expected result |
|---|---|---|
| F01: overlapping levels | Locations A=(0,0,0), B=(0,−2048,0); different IDs; no connecting edge | No route between A/B despite identical X/Z |
| F02: constrained tunnel | Edge width 900 units, height 1200; profile P width 800/height 1100; Q width 1000/height 1100 | P eligible, Q refused for width |
| F03: folded lantern | Same edge as F02; tall profile height 1500, folded profile height 1100; both width 800 | Tall refused, folded eligible only after profile change commits |
| F04: capabilities | Edge requires bits 0b0100; profiles have 0b0101 and 0b0001 | First passes bit test, second fails; species label is irrelevant |
| F05: deterministic queue | One-entry edge; requests at tick 100 from persistent IDs 12 and 7; tie order `(request_tick,persistent_id)` | ID 7 enters first; save/load before admission preserves that choice |
| F06: signed interpolation | From=(0,0,0), to=(0,−1024,0), L=1024, S=256 | After 1/2/3/4 movement ticks Y=−256/−512/−768/−1024; no fifth tick required |
| F07: dive feasibility | Budget 120 ticks; submerged segment 80; contingency 20 | Entry allowed; budget 99 refuses because total requirement is 100 |
| F08: underwater waiting | Begin with 120; consume 80 travel ticks plus 10 wait ticks | Remaining budget 30; pausing for any wall time does not debit it |
| F09: occupied exit | Diving resident owns exit reservation; player tries to remove exit connection | Edit refused; held exit remains valid |
| F10: canopy edit | Resident on branch B; only descent D depends on tree T; request fell T | Refused while route/occupancy would strand the resident |
| F11: conserved fish | Basin stock 10,000 milli-U; bank harvest requests 3,000 and swimmer 4,000 through the same basin | Total committed extraction 7,000; remaining 3,000, subject to existing transaction order; no separate swimmer stock |
| F12: anatomical identity | Change a profile's display species/name while leaving capabilities, dimensions and access policy identical | Physical route eligibility unchanged |
| F13: render independence | Same seed/orders/ticks; compare canopy visible, canopy hidden and forced distant LOD | Identical authoritative hash and route ownership |
| F14: missing transition | Two nearby bank/water locations with no authored connection | No automatic shore crossing from spatial proximity |

F05's tie order is a proposed transition-queue rule. It does not replace the current job-ID path-request ordering. Tests must distinguish those queues. The general shortest-route reference must also be checked against a graph where a cheap nonlocal connection makes the original octile heuristic overestimate, demonstrating why it cannot be copied unchanged.

## 12. Godot integration and outstanding decisions

Godot navigation links connect pathfinding locations but do not themselves implement the special movement between them. This supports using explicit transition logic; it is not a recommendation to replace our deterministic planner with one NavigationAgent per resident. [Godot NavigationLinks documentation](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlinks.html)

Our proposed authoritative graph remains integer data in the existing ECS-style stores. Editor aids may visualize/export connections, but runtime physics, animation completion, IK and GPU results cannot decide route legality or arrival ticks. Presentation can interpolate a committed root and use authored contact poses. Extend the crowd clip catalog, bounds and memory accounting explicitly; its current 16 clips do not include these movement families.

| Owning document / work item | Exact work still required before implementation |
|---|---|
| GDD + setting amendment | Production swimming/climbing profiles under adopted DEC-035; excavation states; terrain/depth extents; transition eligibility; hazards; work/spoil/material accounting; room/service rules across levels |
| Systems architecture | Finite graph/reservation arenas; expanded entity/location identity; memory arithmetic; queue deadlock policy; route planner/cache algorithm; transaction order; save migration |
| Balance | Actual movement/carry profiles, work rates, entry/exit durations, underwater budget/recovery and any supported terrain penalties |
| UI | Registered controls and geometry; layer selection; route feedback; accessible picking; blocked-order explanations; edit previews |
| Assets / animation | Exact species dimension sheets; contact fixtures; traversal clips and sample counts; gear states; bounds; LOD behavior |
| Validation | The fixtures above, conservation and replay tests; domain-crossing bursts; worst-case occupancy; Mac/Windows parity and frame/latency measurements |
| Future battle/campaign | Detection/attack domain matrix; formations at portals; sapping/traps; submerged fire; flyers; moving vessels; rescue/hazard consequences |

Memory derived from a single floor in ARCH-MEM-002 cannot remain unchanged after multi-level construction. The existing scene, navigation and collision budgets also need explicit re-evaluation. The player's 64 GB / RTX 5090 PC can later provide useful evidence, but its availability and specifications do not prove this design fits the existing minimum target.

Recommended next execution order: settle the shared location/connection representation and underground construction amendment first; then define surface swimming and shore transitions, followed by climbable access and canopy work; then add diving and tactical interactions under their own complete rules. This is a dependency order, not a reduction of the already confirmed underground scope.
