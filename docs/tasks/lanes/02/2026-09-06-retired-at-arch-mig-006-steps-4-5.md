# Retired at ARCH-MIG-006 steps 4-5 (2026-09-06)

Task: 02_test_migration_ledger.md
Date: 2026-09-06


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
