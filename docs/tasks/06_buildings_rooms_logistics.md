# Task 06 — Buildings, rooms, equipment and logistics

2026-09-09 · PLANNED milestone card; expand into increments before coding.
Owning contracts: GDD §4, §5.7–5.9 (REQ-SET-081–142 as reading context),
architecture §2/3/6/7, ARCH-SYS-015/016/019/021, balance construction/storage/work
rules, DEC-010/029/031, MOVE-REQ-002–008/013/019 and task-06 requirement CSV rows.

## Dependencies and contract work

Task 04 commands/initializer and task 05 shared spatial identity/access are
prerequisites. The minimal starter building/container/bed/gear slice is pulled
into 04.3; extend it here rather than create parallel structures. Task 03 owns
fishing stocks and producers. Resolve PC-05 in the roadmap: room service/contact
identity, real heat/light/workshop factors, gear custody and installed boat
ownership; review R06 adoption before using its proposed allocator columns.
Expanded construction needs G01 costs/spoil/support/hazards and G02 capacity/
atomic-edit contracts. Open gates block their dependent modes, not surface rooms.

## Dependency-ordered work

- [ ] 06.1 Complete packed Building, Construction, Furniture, Room, service and
  storage indexes; strict capacities/ref reuse and future save fields. Integrate
  PLACE_BLUEPRINT/PLACE_FURNITURE/DESIGNATE_ROOM/UPGRADE/DEMOLISH/SET_DOOR_OPEN.
- [ ] 06.2 Implement delivered material/WIP, staged work and cancellation/refund
  contracts, worker replacement, work contacts, upgrades and atomic completion.
  Service topology follows real doors/transitions; underground and surface rooms
  share rules and inventory access. Refuse occupied/only-exit destructive edits.
- [ ] 06.3 Complete dynamic room enclosure, occupancy, warmth/fuel and workstation
  context under actual day/season order. Wire RoomHeat once and feed exact work
  factors with one final floor; keep render lighting separate from authority.
- [ ] 06.4 Complete physical hauling and output/source reservations, storage
  filters/minimums/mass limits, carry/ground-pile recovery, gear wear/equipment
  swaps and shared instance allocator; integrate SET_STORE_FILTER,
  SET_STORE_MINIMUM and EQUIP through the task-04 dispatcher. A fishing boat's installation and owner
  need a declared contract; do not fabricate a `boat` inventory item.
- [ ] 06.5 Finish all three interoperable underground tools with task 05, varied
  dwelling forms, furnishing and room/logistics UI. Record material/work/spoil
  accounting and exactly when completed geometry becomes traversable.

## Acceptance and evidence

Test overlapping delivery/consumption, full destination, cancelled construction,
worker death, slot reuse, equipment ownership, no duplicated starter tools,
partially delivered WIP, exact refund/sink accounting, reachable and unreachable
services and rooms at the same X/Z on different levels. Refused edits preserve
world/materials; committed tunnels persist after builders leave. Run GDD worked
fixtures and current headless suite, then visible build→deliver→work→occupy→heat
on Mac with a command trace and conservation ledger. Update save/memory schema,
per-stage costs and test migration ledger as each store lands.

Implementation lead owns shared composition and topology protocol; buildings
coder owns building/room modules, logistics coder inventory/gear adapters under
an agreed allowlist, QA owns independent acceptance. One writer per file.
Completion establishes usable supplied spaces and equipment in the implemented
scenario, not complete seasonal food, families, all scenarios or release parity.
Next dependency: task 07 production and task 08 care/community integration.

## 2026-09-11 building-domain ruling — definitions resolved

Read [R-BUILD-DOM-001–004](../rulings/2026-09-11_building_room_domains.md)
and its adjacent JSON specification fixtures. Decision 0056's unlock domain,
Station domain, furniture-mask assignment and fifth-shelf interpretation are
resolved. Publish Milestone/Station through the existing registry, then implement
packed stores and dependency-ready starter composition; do not reopen these as
undefined fields or declare absent service/topology owners complete. Run the
ruling's exact mapping, mask, ownership, capacity and failure tests.

## Art authoring contract — 2026-09-11

Use [ART-GAP-R03/04](../planning/asset_dimensions_and_budgets.md) for all30
exterior-height envelopes, non-creature budgets, explicit cutaway parts and
stockpile fill truthfulness. They add no storage capacity, room service or
underground depth. One8×8m stockpile remains one400000g container; do not multiply
capacity by its sixteen footprint tiles. Runtime/export/performance evidence
remains required separately from these authored ceilings.

## 2026-09-11 — 06.1's first increment landed

[Decision 0080](../decisions/0088-the-packed-building-room-and-furniture-stores.md) publishes the Milestone and Station domains and lands the packed **Building, Room and Furniture** stores with R-BUILD-DOM-003's presence mask, the earned-bit unlock gate, the §4.1–4.3 catalog facts and the Station provider binding. 06.1 stays **unchecked**: its **Construction** store, its **service and storage indexes**, and the PLACE_BLUEPRINT/PLACE_FURNITURE/DESIGNATE_ROOM/UPGRADE/DEMOLISH/SET_DOOR_OPEN command integration are not done, and neither is composition into `settlement_system.gd`. Read 0080's "What is deliberately NOT implemented" before extending any of it.
