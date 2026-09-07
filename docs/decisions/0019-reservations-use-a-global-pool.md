# 0019 — Reservations use a global pool, not owner-major indexing
Date: 2026-09-06 · Status: **Accepted** (Brendan, 2026-09-06) · Resolves: **U4**

## Decision
32768 reservation rows allocated **globally from the lowest free index**. There
is no `job*4+i` indexing.

## Why the 4:1 ratio was a red herring
32768 rows against 8192 jobs is a **storage budget, not a recipe rule**. Reading
it as owner-major would cap a recipe at four input lots — and even a
two-ingredient recipe can need more than four lots once inventory is fragmented.
Task 2.5 deferred this rather than guess, which was the right call.

## Rules
- Variable-length reservation lists per Job and per inventory lot.
- Shared input claims belong to the **coordinator** (decision 0017).
- Coalesce claims with identical `(job_ref, lot_ref, purpose)`.
- **Preflight the complete transaction.** Insufficient rows produce an explicit
  capacity refusal and **no partial reservations**.

## Invariant
```
lot.reserved_milli = sum(active reservation quantities for that lot)
                   <= lot.quantity_milli
```

## Packed indexing layout

| Allocation | Bytes |
|---|---:|
| Occupancy: byte × 32768 | 32,768 |
| Free-row min-heap: int32 × 32768 | 131,072 |
| Heap count: int32 | 4 |
| Job list heads: int32 × 8192 | 32,768 |
| Lot list heads: int32 × 16384 | 65,536 |
| Prev/next links by job and lot: four int32 columns × 32768 | 524,288 |
| **Additional indexing payload** | **786,436** |

Additional to the existing 1,179,648-byte reservation payload. **Coordinator
bookkeeping is budgeted separately** and is not included here.

## Acceptance
Each must preserve ownership and inventory totals: reserve a recipe across
**five or more lots**; exhaust the pool; spoil a reserved lot; replace a party
member; save and load active claims.

## Source
Brendan, 2026-09-06, resolving U4 from `docs/tasks/02_settlement_foundation.md`.
