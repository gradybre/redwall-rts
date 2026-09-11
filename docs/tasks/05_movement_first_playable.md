# Task 05 — Movement and the first playable checkpoint

Status: **PLANNED; engineering proposals explicitly unratified; no implementation or gate closure claimed**. Prepared 2026-09-09. Companion: [Movement contracts](../planning/movement_contracts.md). Coordinate initialization with [task 04](04_world_commands.md), sequencing with the [release roadmap](00_release_roadmap.md), and checkpoint evidence with [first-playable acceptance](../planning/first_playable_acceptance.md). Track requirement evidence in [requirements.csv](../planning/requirements.csv).

## Authority, starting point, and outcome

Read [AGENTS.md](../../AGENTS.md), [SET-MOVE-001](../movement_direction_amendment.md), [GDD](../game_gdd.md) §§5.1–5.3, 5.9, 5.11, [architecture](../systems_architecture.md) §§2–9 and ARCH-MOVE-001, [UI-MOVE-001](../ui_ux_controls.md#ui-move-001--required-connected-movement-controls), [traversal review](../art-reference/traversal_design_review.md), and decisions 0020/0025. The amendment supersedes release-wide ground-only assumptions; review fixture values remain synthetic.

[STATUS](../STATUS.md), dated 2026-09-09, reports task 03 at six of ten increments, eighteen idle architecture stages, no Transform/navigation/save implementation, no command delivery, and no job producer. These claims and its 1224-test count are reported, not independently verified by this planning review. Its statement that no task 04 exists describes that snapshot. Recheck code and owning decisions before dispatch. READY_06 answers include unadopted recommendations: verify adoption item by item before replacing an older blocker description or using a proposed value.

Deliver the movement contribution to the observable loop: player order → concrete reserved job → legal travel → supported work contact → work → conserved output/haul → renewed work or needs. A ground/ford demonstration is the **intermediate first-playable checkpoint**, not connected-movement completion or full settlement release. Persistent tunnels and inhabited underground rooms from all three construction tools, swimming/diving, climbing and canopy work remain required first-release scope. Combat, free flight, moving vessels, and arbitrary jumping are not added.

## Dependencies and entry conditions

| Dependency owner | Exact handoff needed | What it blocks |
|---|---|---|
| [Task 04 — World and commands](04_world_commands.md) | Ordered commands and payload validation, paused previews, concrete GDD initialization, actual job producers and output commits; world generation consumes the shared identity interface frozen with task 05 | Player-driven checkpoint; movement stores may proceed against explicit fixtures |
| Task 03 completion | Ecology/crop stages, accepted job-trigger rulings, existing basin ownership, gear and effort-claim integration where used | Live forage/farm/fishing demonstrations; a passing stock reader is insufficient |
| GDD/balance owner | MOVE-G01 outputs listed in companion: finite geometry, profiles, construction accounting, interruption/hazard matrix | Full G02 binding/closure and affected expanded production modes; reviewed independent ground/interface slices may proceed |
| Buildings/rooms/logistics owners | Work/service contacts, room access, inventory-load revision, construction completion and edit intents | Real needs destinations, hauling, persistent underground publication |
| Save owner | Canonical serializer, checkpoint hash, disk-backed rollback loader and version policy | Any save/next-tick parity claim; an in-memory clone cannot substitute |

Audit actual handoff behavior before integration. If a prerequisite is absent, record the blocked acceptance and owner; never create fake jobs, remote work, or fabricated starting resources to make a demo appear complete. Keep 12 initial adults/IDs 1–12, Rowan, prescribed needs/equipment/inventory, hall services and seed 20260905 consistent with GDD initialization. Do not duplicate the twelve equipped starter tools.

## Ownership and optimized subagent plan

Use a lead plus at most three bounded implementation lanes after interfaces freeze. Each lane receives only relevant spec sections, signed interface tables, its file allowlist, and acceptance IDs. Return a short result/blocked-evidence report; do not send every lane through the whole repository. Parallelism here describes implementation staffing, not multithreaded simulation.

All paths below are repository-relative. Every new module path is **proposed**, not an existing module. The integration lead schedules shared-file handoff across tasks 03/04/05 and is the sole integration writer of `godot/scripts/systems/settlement_system.gd`, `game_manager.gd`, `ui_manager.gd`, `godot/scripts/core/jobs.gd`, `work.gd`, `reservations.gd`, `entity_directory.gd`, and test-runner registration. Movement/inventory/needs/world/save owners supply narrow patches; no concurrent shared-file edits.

| Lane | Exclusive proposed files | Bounded deliverable |
|---|---|---|
| A: spatial/topology | `godot/scripts/core/spatial_world.gd`, `topology_edits.gd`; `godot/test/test_spatial_world.gd`, `test_topology_edits.gd` | Typed handles, common contacts, atomic publication/refusal |
| B: routes/motion | `godot/scripts/core/navigation.gd`, `movement.gd`, `crossing_claims.gd`; corresponding proposed `godot/test/test_navigation.gd`, `test_movement.gd`, `test_crossing_claims.gd` | Deterministic routing, admission, progress and bounded storage |
| C: presentation | `godot/scripts/ui/movement_panel.gd`, `godot/scripts/render/settlement_movement_view.gd`; proposed `godot/test/test_movement_ui.gd` | Registered controls, snapshots, interpolation and clip validation |

Lane B may start an independently reviewed ground/interface slice after A's matching identity contract; expanded production work requires its binding G01/G02 inputs. C can draft registry/layout alongside A/B, but final assets follow clearance. Run one independent acceptance review after integration. The integration lead coordinates updates to owning specifications, decisions, STATUS and memory ledger.

## Dependency-ordered increments

### 05.1 — Freeze contracts and closure evidence

Two dependency outcomes are distinct. **05.1a: reviewed ground/shared-interface slice.** Record its adopted inputs, typed handles/sentinels, supported ground profiles and contacts, baseline-only capacities/bytes, transaction/refusal semantics and save obligations. Review independence from unresolved modes and freeze that interface before coding. This permits affected ground work and synthetic expanded-graph fixtures while other profiles remain open; it grants neither expanded capacities nor full gate closure.

**05.1b: full connected-movement contract.** Full G01 precedes FULL G02 binding/closure. Adopt or revise all geometry, construction, profile and interruption inputs, then bind complete packed schemas, expanded capacities, transactions and migration. UI design proceeds alongside architecture. Record requirement/increment/evidence/blocker mappings in `../planning/requirements.csv`. All companion proposals remain unratified until their owner records adoption. “Closes” below means future conditional acceptance, never closure awarded by this plan.

Acceptance: 05.1a identifies exactly which work may proceed; every other mandatory mode has an adopted policy row or named blocker. No guessed depth, species capability, excavation price or air budget. **Closes:** only reviewed slice decisions initially; full G01 requires all binding outputs, and full G02 follows it. **Does not close:** any full gate through slice review alone.

- [x] **05.1a — recorded and implemented, 2026-09-11.** Entry artifact: [movement ground slice entry](../planning/movement_ground_slice_entry.md); engineering record: [decision 0053](../decisions/0053-movement-ground-slice-identity-and-storage.md). Delivers `spatial_world.gd`, `navigation.gd`, `transforms.gd` and `movement.gd` with their suites, against READY_07 §1.2's acceptance list. Ledger advanced by 520192 bytes for three enumerated new rows. **Closes no gate.** Save round trip is BLOCKED on the canonical serializer; the ARCH-PATH-003 macro-anchor detour is measured and raised, not silently worked around; no profile, clearance, facing or turn-cost value was invented.
- [ ] **05.1b — not started.** Waits on the MOVE-G01 parameter pack (READY_07 §1.3).

### 05.2 — Shared space, transforms and initial contacts

Ground/shared-interface work depends on **05.1a**, not completion of every G01 profile, plus the matching world handoff. Implement generation-validated locations/connections with domain, level and integer XYZ; connect resident positions, job contacts, beds, rooms, containers, resource work points and picking to those identities. Initialize previous=current. Same-X/Z multi-level synthetic fixtures establish identity isolation, not production extent. Ground navigation uses existing 0.5 m cells; expanded allocations/activation wait for 05.1b.

Acceptance: F01/F14; reachable initial hall/well/stores, resource approaches and map exit; invalid mandatory handles reject safely. **Closes:** shared-identity portion of G02 and MOVE-REQ-001/013 evidence. **Leaves open:** expanded topology, routes, UI and G05 completion.

### 05.3 — Reference routes, cache and readiness

Ground implementation depends on 05.2's reviewed slice and matching routing contract. Build synthetic expanded-graph Dijkstra reference fixtures in parallel; expanded production routing waits for 05.1b. Implement deterministic requests, quota accounting, exact contacts, bounded route arena and cache for the reviewed scope. Flat octile A* is valid only on its original graph; optimization needs admissibility and reference agreement. Preserve search state and publication timing for saves.

Acceptance: cheap nonlocal shortcut, disconnected macro starts, stale profile/topology, full referenced route arena, partial heap and deterministic tie fixtures. Measure queue wait separately from search. **Closes:** routing portion of G02/MOVE-REQ-005/006. **Does not establish:** the 0.25-second latency target or full G05.

### 05.4 — Integer motion, constrained admission and work arrival

Depends on the matching 05.3 slice and job/logistics interfaces; ground progression does not await expanded-mode activation. Wire Navigation/Movement after selection and before ProductiveWork in the direct-call tick pipeline. Use ground speed remainders, validated segments and domain-aware separation; arrival requires the exact compatible work contact. Preserve JobState IDs; separate planning from crossing queues. Admission atomically claims passage and safe landing. Waiting owners renew travel leases; occupied transitions retain commitments through cancellation.

Acceptance: RESERVED → TRAVEL → WORK → output/haul without travel producing WU; F02–F06; opposite-direction traffic, full landing, starvation and deadlock refusal; inventory/profile change before entry. **Closes:** ground motion/admission portions of G02. **Leaves open:** production swim/climb/dive interruption and all release-wide gates.

### 05.5 — Needs, lifecycle and visible ground checkpoint

Depends on 05.4, real job production, reachable services and UI snapshots. Support safe feeding/rest/social travel; preserve existing need remainders and urgency. Death releases jobs/claims once, preserves recoverable inventory and history; departure removes population only at the map exit. Return unsafe-transition interruption cases to G01 instead of forcing floor sleep in water or on a ladder.

Acceptance: start paused; queue an order; resume and observe travel/work/output, hunger diversion and return. Repeat at 1×/2×/4× and hidden/distant views with equal-tick state agreement. List absent ecology, room, save or needs services explicitly. **Closes:** intermediate checkpoint only when its real loop works. **Does not close:** G01–05 as a group, complete survival simulation, or first release.

### 05.6 — Persistent underground construction and topology edits

Expanded production depends on 05.1b, approved G01 construction accounting, 05.2–05.4, and construction/rooms owners. Placed burrows, planned rooms/tunnels and free multi-level excavation share planned/working/completed state, accessible work faces, material/spoil transfers and topology publication. Builders leaving never removes finished routes. Edits check occupants, crossing/exit claims, dependent rooms/services and safe returns before publication.

Acceptance: MOVE-TEST-01/02/05/10; interrupt every transaction boundary; exhaust pools without partial holes, lost materials or stranded occupants. **Closes:** underground/topology G02 portion. **Leaves open:** corresponding art, UI and measured G05 evidence until supplied.

### 05.7 — Water and canopy production modes

Depends on approved per-mode profiles, 05.4/05.6, and valid clips. Implement shore entry/surface swimming, ladder/trunk/branch contacts and supported canopy work/return; then bounded dive plans with reserved air exits and tick-accounted budget including waits. Check each party member. Aquatic fishing uses existing basin stock/whitelist and effort claims.

Acceptance: F07–F12, MOVE-TEST-04/07; missing exit, insufficient air, load/grip refusal, cancelled crossing, removed descent. **Closes:** remaining movement behavior portions of G02 when complete. **Does not close:** G03/G04 through proxy visuals or G05 through synthetic-only evidence.

### 05.8 — UI, rendering and save integration

Depends on mode contracts; UI design proceeds alongside G02. Register layer controls, route panel, focus, picking and edit previews across 1280×720–3840×2160. Render domain-correct movement at all LODs, safe interpolation, supported contacts and explicit pending cancellation. Add versioned movement sections to the real serializer and loader.

Acceptance: MOVE-TEST-03/06/08; missing clip rejected; prior/current pose timing survives pause/load; corrupt incoming save preserves old world. **Closes:** G03/G04 only with complete registry and exported asset evidence; save portion of G02. **Leaves open:** full G05 until integrated verification.

### 05.9 — Integrated qualification and release accounting

Depends on all preceding increments. Compare every tick, including 3001–18000 after saving at 3000, and forks at midnight, queue admission, partial search, active crossings, death and topology commit. Run F01–F14 plus MOVE-TEST-01–10, capacity/refusal and cache/deadlock fixtures. Record source/build/catalog hashes, exact inputs, commands, hardware, per-tick digests and first divergence.

Measure 256 living residents at 1×/4×, route-ready latency, all packed capacities, snapshot copies, transient/load peaks, UI and rendering. Keep verification hashing cost separate. Mac evidence continues; unavailable Windows/5090 evidence stays deferred and does not replace qualification-floor measurements. **Closes:** G05 only with complete reproducible required evidence. A partial report lists each open gate, missing artifact and owner; it never renames the ground checkpoint “movement complete.”
