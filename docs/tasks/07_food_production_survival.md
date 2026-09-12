# Task 07 — Food production, consumption and seasonal survival

2026-09-09 · PLANNED milestone card; expand before coding.
Owners: GDD §5.2, §5.4–5.8, §5.10, §7.1; SET-AMEND-001 diet/catalog changes;
gameplay_balance BAL-WORK-001 and recipe/food/ecology fixtures; architecture
ARCH-SYS-003/004/013/014/015/021 and task-07 requirement CSV rows.

## Dependencies and unresolved contracts

Task 03 provides running ecology, weather/crops, harvest demand and fish stocks;
task 05 physical work/carry/service access; task 06 rooms, gear and warmth.
Use PC-05's actual weather/darkness/workshop inputs before certifying WU.
Family demand is PC-04/task 08: adult tests cannot establish dependents' survival.
Task 09 supplies production save parity; isolated winter control remains a
reference, not the release simulation. Resolve R06 adoption and changed hashes
explicitly for additive regrowth/other behavior changes.

## Work and ownership

- [ ] 07.1 Compile/validate only active recipe definitions and dependencies,
  unlocks, quantities, yields, quality, equipment and WU. Implement finite orders
  and stock targets; feed one producer into JobPlanner, integrate EDIT_ORDER.
- [ ] 07.2 Implement batch/WIP/manual/passive phases, atomic input capture and
  outputs, shared coordinator progress, replacement workers and exact XP. No
  research candidate activates through name matching. Preserve retired hunting
  enum slots and v2 nut-roast/amended feast inputs.
- [ ] 07.3 Implement real eating/drinking/cooking service acquisition, carried
  meals, interruption/refund rules, restoration/memories and starvation/health
  integration. Stock aging, spoilage and transformations run once in their
  architecture phase, including shared hour/midnight ticks.
  - **The aging/spoilage half of 07.3 is done** — ARCH-SYS-004 StockAge is
    `godot/scripts/core/stock_age.gd`, driven hourly from `settlement_system.gd`
    and logged as REQ-SET-007's first daily leg before the season handover
    ([decision 0085](../decisions/0085-stock-aging-runs-hourly-and-declares-its-store.md)).
    The item remains open for eating/drinking/cooking service, carried meals,
    interruption/refund and starvation integration. Two of the three things aging
    owed in that record are still owed: a container's store kind has no
    building-layer owner and must be declared, and REQ-SET-108's replanning has no
    recipe or meal store to notify.
  - **The seed → compost quantity is settled and implemented** (2026-09-12).
    [STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md) supplies
    `floor_div(checked_mul(q_milli, seed_mass_g), compost_mass_g)`, per lot, with
    the remainder booked as decay loss and a zero yield retiring the lot;
    `stock_age.gd` implements it and
    [decision 0090](../decisions/0090-expired-seed-converts-to-compost-by-floored-nominal-mass.md)
    records the judgements. **Two parts of that ruling are NOT done and are not
    this module's to do:** the seed-consumer eligibility guard exists as
    `StockAge.refuses_seed_consumption()` but **nothing calls it** — enforcement
    is `inventory.gd`'s under the ruling's own ownership split — and the blocking
    critical-pause plus exactly-once retry belong to `settlement_system.gd`.
    Continuation through the real hourly caller, save/reload and the starter
    economy remains open exactly as decision 0085 left it.
- [ ] 07.4 Complete sustainable forestry, crop rotations, orchards/hives, fishing
  gear/effort and preservation chains through physical work and storage. Initial
  basin stocks never multiply with player zones. Integrate SET_FIELD_ROTATION
  with task-03 policy state and REQUEST_RELIEF_SEEDS with its annual limit,
  next-dawn delivery and saved assistance event. No remote harvesting or instant
  output delivery is introduced for winter success.
- [ ] 07.5 Provide honest food/fuel forecasts, ingredient and blocked-order
  explanations, production screens and season preparation guidance. Reconcile
  current needs/CareHealth phase deviation with owning interval contract while
  integrating injury/treatment; avoid double application.

Production coder owns recipes/batches/consumption; task-03 owner owns ecology
corrections; integration lead owns common stages; UI owner owns production
screens; independent test runner owns conservation and timing evidence.

## Acceptance and limits

Run GDD §7.1 arithmetic fixtures through runtime APIs, then scenarios covering
reserved ingredient expiry, full output storage, batch cancellation, death,
carry loss, shared workers, no double aging, calendar boundaries and exact
nutrition/quantity/work/XP ledgers. Maintain all six golden-fixture families
(U7) as explicit fixtures, not a quoted historical assertion total.

Execute full-runtime winter and longer survival trajectories from legal seeds
and reproducible command policies. Record inputs, initial/remaining/WIP/consumed/
spoiled stocks, daily population/needs/deaths, source/sink totals and omitted
systems. Report failures without improving stock or disabling hazards. Compare
with isolated controls only over common contracts. Measure integrated release
stage costs; per-kernel medians do not establish combined p99.

Completion proves the tested integrated food chains and seasonal scenarios.
It does not prove Charter progression, every scenario/dependent profile,
complete save parity or minimum-hardware performance. Continue task 08 and
expand these runs after family and scenario contracts are implemented.
