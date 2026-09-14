# 2026-09-12 — 06.1's Construction store and its lifecycle

Task: 06_buildings_rooms_logistics.md
Date: 2026-09-12


[Decision 0131](../decisions/0131-the-construction-store-owns-the-project-lifecycle-not-a-second-building-store.md)
lands `godot/scripts/core/construction.gd` and composes it into `settlement_system.gd` over
decision 0087's Building store. It implements REQ-SET-124–128 and REQ-SET-137: delivery before
work, consumption at one transition when work begins, the 100%-before / 80%-after cancellation
refund floored to milli-U, evacuation before demolition, and a demolition priced at the declared
construction WU × 0.25 that returns 50% of the original §4.1 material cost. Cancellation and
completion are both two-phase with an idempotent retry, so a failed output publishes nothing and
leaves every collaborating store byte-identical. §4.1/§4.2/§4.3's `materials_milli` pair lists
live in this store, which is the choice decision 0088 deferred to it; `building_definitions.gd` is
byte-untouched.

**06.1 stays unchecked.** Not done, and not started: 06.1's **service and storage indexes**, and
the **PLACE_BLUEPRINT / PLACE_FURNITURE / DESIGNATE_ROOM / UPGRADE / DEMOLISH / SET_DOOR_OPEN**
dispatcher integration. No Job is created for REQ-SET-124's delivery or build work, nothing calls
`add_work_mwu()`, and `TICK_STAGE_COUNT` is still 8 with every stage keeping its name. **The §7.2
starter settlement is NOT built**: decision 0087's five blockers are all still open and a
generated settlement holds 0 buildings, 0 rooms, 0 furniture and 0 projects, which a test pins.

Three things are owed by owners other than this change:

- **A `docs/systems_architecture.md` §3 entry** for the three new column groups (5 142 528 bytes)
  and the seven §2.3 totals that follow from it. Decision 0131 prints the byte arithmetic.
- **A `docs/persistence_state_registry.md` section** for `construction.gd`. Until it exists
  `state_registry_coverage.py` FAILS with `C1 construction.gd has no registry section`, so
  `tools/run_tests.sh` and CI fail while the Godot suite is green. The exact fourteen-row block is
  in decision 0131's evidence and was verified against the checker before being handed over.
- **REQ-SET-128's stored-goods gate.** The resident half is enforced against the real Building
  store, with the exact blocked count in the refusal. The goods half needs `inventory.gd` to
  publish a container-by-owner enumeration; it has none, and no caller-attested boolean was
  accepted in its place. This blocks 06.2's "Refuse occupied/only-exit destructive edits".

One contract is unresolved and was not invented: **whether a tier-2 package's materials and work
join a demolition's basis**. REQ-SET-127 says "50% original material costs" and §4.2's upgrade
table declares no demolition consequence, so the store uses the base §4.1 row at every tier and
says so.
