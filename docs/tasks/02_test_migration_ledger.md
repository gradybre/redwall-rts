# Test migration ledger — task 02

Every prototype test is **retained**, **replaced**, or **retired with a reason**.
Prototype behaviour that contradicts the specification is not preserved merely to
keep an assertion green (ARCH-MIG-006).

Per ARCH-MIG-006 step 2, the prototype suites **keep running unchanged** against
the prototype modules while replacements are built beside them, so a failure has
a known cause. Nothing under `godot/scripts/systems/` or
`godot/scripts/components/` was edited in this task.

| Suite | Baseline | Now | Disposition |
|---|---:|---:|---|
| `test_entity_manager.gd` | 16 | 16 | Retained, still green. Semantics ported to `test_entity_directory.gd`; one contract inverted (below) |
| `test_economy_system.gd` | **16** | 21 | **Replaced** (step 5). Float model retired with `EconomySystem` itself. *Ledger previously said 15; the file held 16* |
| `test_game_manager.gd` | 10 | 20 | **Replaced** (step 4). `GameManager` is now a thin adapter over `sim_clock.gd` |
| `test_combat_system.gd` | 9 | 9 | Retained as **legacy battle-layer** only (ARCH-MIG-004). Not settlement coverage |
| **New core suites** | 0 | **192** | `test_int_math` 33, `test_catalog` 18, `test_entity_directory` 27, `test_sim_clock` 30, `test_inventory` 54, `test_item_definitions` 12 |
| **Total** | **52** | **257** | 2762 assertions, 0 failures |

## Contracts deliberately inverted

**`test_destroyed_ids_are_never_reused`** (`test_entity_manager.gd:50`) asserted
that a destroyed id is never handed out again. The GDD requires the **opposite**:
`EntityRef = (slot, generation)` with slots reused under generation validation
(GDD §4.1). The prototype test stays green against the prototype, but the
release contract is inverted in `test_entity_directory.gd`, which asserts
lowest-free-slot reuse with a generation bump that invalidates the stale ref.
The half of the original intent the spec keeps — persistent IDs never being
reused — is preserved as a separate test.

## Tests that will retire rather than migrate

These exist **only** because of float defects that cannot occur in the mandated
integer model. They are not adapted; the bug class disappears.

| Test | Why it retires |
|---|---|
| `test_small_rates_are_not_discarded_at_high_stock` | Guards float epsilon starvation. `is_equal_approx` has a magnitude-scaled tolerance, so small deltas vanish as a stockpile grows. With `quantity_milli:int64` and retained remainders there is no dead band |
| `test_exactly_affordable_cost_is_payable_after_float_accumulation` | Guards `SPEND_TOLERANCE = 0.0001`, a workaround for float accumulation error. Integer milli-units accumulate exactly; the tolerance has no analogue |
| `test_cycle_speed_wraps_through_multipliers` | Asserts a 3-speed cycle including **3x**, which REQ-SET-003 forbids |
| `test_cycle_speed_drives_the_engine_clock` | Asserts `Engine.time_scale` drives simulation time. Authoritative time is integer fixed ticks; host scaling is a scheduler input, not the clock |
| `test_thousand_entity_lifecycle_within_frame_budget` | Retained as a stress margin, but 1000 exceeds the 256 cap. Re-targeted at the real cap in the new suite; the 1000-row version is explicitly labelled as exceeding the specified maximum |

## Coverage this milestone does NOT provide

Needs, jobs, schedules, ecology, crops, weather, buildings, rooms, recipes,
feasts, immigration, progression, movement, pathfinding, saves, replay parity,
UI snapshots, and the BAL-RUN strategy automation. No performance claim on the
qualification hardware. No survival trajectory. The reservation **row store** is
absent (blocker U4) — only the per-lot `reserved_milli` invariant is covered.

## Retired at ARCH-MIG-006 steps 4-5 (2026-09-06)

Retired because the defect class disappears under integer arithmetic:

| Test | Reason |
|---|---|
| `test_small_rates_are_not_discarded_at_high_stock` | Guarded float epsilon starvation. Covered in spirit by `test_repeated_small_deposits_stay_exact`, which needs no tolerance |
| `test_exactly_affordable_cost_is_payable_after_float_accumulation` | Guarded `SPEND_TOLERANCE`. Integer milli-units accumulate exactly |

Retired because the specification contradicts the asserted behaviour:

| Test | Reason |
|---|---|
| `test_cycle_speed_wraps_through_multipliers` | Asserted a 3x cycle; REQ-SET-003 forbids 3x |
| `test_cycle_speed_drives_the_engine_clock` | **Contract inverted** — now `test_engine_time_scale_is_never_written` |
| `test_add_resource_clamps_at_cap` | **Contract inverted** — REQ-SET-110/120 require explicit refusal, not silent clamping |
| `test_set_cap_clamps_existing_stockpile`, `test_lowering_a_cap_does_not_report_depletion` | No per-resource cap exists; REQ-SET-120 forbids deleting stored goods to fit a smaller store |
| `test_tick_applies_net_rates` | Invented per-second production. Production comes from jobs and recipes, which this milestone does not build, so there is no replacement |

Everything else was **re-expressed, not weakened**: elapsed seconds became completed
ticks, float consume became integer withdraw, and the 2 ms tick budget became the
2 ms summary-recompute budget.

## What the HUD honestly shows

Populated: **Ready NP** (the food-days *numerator*, derived from edible,
non-seed, unreserved, unexpired lots — reproduces the GDD §7.1 starter fixture of
exactly 408,000 NP), **Wood**, **Stone**.

Left as `--`, never a fabricated zero: **Food-days** and **Fuel-days** (their §5.8
divisors need resident demand and heating demand, which do not exist),
**Residents** and **Beds** (no model yet).

Aging and spoilage are **inert** — `_is_expired()` is implemented and tested but
always returns false, because store and temperature factors come from systems this
milestone does not build.
