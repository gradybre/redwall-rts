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
