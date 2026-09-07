# 0020 — MOVE-G01–05 close in dependency order
Date: 2026-09-06 · Status: **Accepted** (Brendan, 2026-09-06)

## Decision
The gates are retained. The movement **direction** is already adopted
(`SET-MOVE-001`, DEC-035) — re-approving the concept would not close them.
They require engineering work, in this order:

| Sequence | Work |
|---|---|
| **First: G01** | Finite world/depth bounds, traversal capabilities, construction costs, hazards, interruption rules |
| **Next: G02** | Packed schemas, capacities, full memory ledger, routing, reservations, save migration |
| **Alongside G02: G03** | Layer selection, route inspection, editing previews, blocked-state UI |
| **After scale/clearance: G04** | Movement clips, transitions, contact rules, asset budgets |
| **Throughout, closing last: G05** | Correctness fixtures, replay parity, capacity exhaustion, performance evidence |

## Consequences
- Independent settlement work continues unblocked.
- **The production connected-movement pathfinder follows the expanded
  contract.** The existing one-floor ledger cannot qualify it — do not present
  it as sufficient.
- G04 depends on the scale decision (0002), so scale is on the critical path for
  movement assets.
- Windows measurement stays deferred. The 5090/64 GB machine gives useful
  evidence but **does not establish minimum-spec performance**.

## Source
Brendan, 2026-09-06.
