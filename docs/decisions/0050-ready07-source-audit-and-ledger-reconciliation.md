# 0050 — READY_07 source audit, ledger reconciliation and performance ownership

Date: 2026-09-11 · Status: Accepted for arithmetic/source corrections and ownership;
new scheduler/Weather/movement engineering proposals remain proposed.

## Decision

Use the mechanical allocation sum as the current planning memory basis:60256806
payload bytes,68645414 with reserve,31354586 headroom; rejected two-world peak
122686636, exceeding 100000000 by 22686636. Append the previously uncarried437632
once to the historical reconciliation trail, without adding it to field rows
that already include it. Preserve historical values as historical.

Assign ADR0016 to the implementation lead, with independent performance review.
The issue remains open. Re-measure current integrated release work; do not treat
the initial1.19ms development result as today's p99 or as hardware qualification.

## Source audit findings

GDD §5.9 already locates and sizes starter buildings; `inventory.gd` already owns
InventoryContainer storage. The main-scene cohort exists separately from the
incomplete generated world. Correct the corresponding “nowhere specified” /
“no container store” claims without pretending bootstrap integration is done.
Task05.1a permits reviewed ground/shared-interface work; full MOVE-G01–05 are
not prerequisites to all engineering and are not closed by this document.

## Scope and evidence

[READY_07 answers](../rulings/2026-09-11_ready07_open_item_answers.md) contain
checked catalog mappings, corrected startup dependencies and the next execution
sequence. The companion scheduler record, Weather identity fields, starter
opening positions and full-profile design work are explicitly engineering
recommendations. No gameplay parameter or movement gate is implicitly approved.

[Memory audit](../rulings/2026-09-11_ready07_memory_audit.md) records every printed
allocation row. Arithmetic is not a measured runtime allocation or a complete
expanded-world ledger. Current code/source reviewed at 16e1efc; the executor's
1999-test report was not rerun during this review. No runtime code changed.
