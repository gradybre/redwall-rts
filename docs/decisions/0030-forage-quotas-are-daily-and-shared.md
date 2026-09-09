# 0030 — Forage quotas are daily, aggregate, and shared by the basin
Date: 2026-09-09 · Status: **Accepted — user-approved planner contract**
Supersedes the provisional annual per-patch enforcement in
[0026](0026-forage-patches-belong-to-the-basin.md)
Amends: `game_gdd.md` §4.2 and §5.5, `systems_architecture.md` §2.2

## Correcting the record first
This repository — including my own brief to the planner — stated that
`quota_milli` had **no stated period anywhere**. **That was wrong.**
`ui_ux_controls.md:219` (UI-SET-050) already labels the quota
`"Harvest quota " + U + " units per day"`. The period was stated; it was stated
in the UI document, and I searched only the GDD and the architecture.

The real defect was narrower and remains real: **the UI stated a daily period
that the GDD and the forage accounting gave no contract for.** `FishStock` has
`harvested_today_milli`; `ForagePatch` has only `harvested_year_milli`, and
`HarvestZone.quota_milli` had no period of its own. The implementation therefore
measured quota against each patch's annual total, inventing both an annual period
and a separate allowance per forage kind.

The lesson is procedural: **a "nothing states this" claim has to be checked
against every owning document, not just the ones that usually own it.**

## The approved contract
1. `HarvestZone.quota_milli` limits **total forage collected per calendar day
   across all five kinds** — not per kind, and not per year.
2. The **basin** limit is shared across every designation drawing from it.
3. A designation may impose an **additional, stricter** local limit.
4. `ForagePatch.harvested_year_milli` remains **annual ecological history** and
   is not the quota accumulator.

Daily collected and outstanding-reserved totals live on `HarvestZone`, where both
limits live. With `Q` effective daily quota, `H` collected today and `R`
outstanding reserved, all nonnegative int64 milli-U:

```
available_quota = max(0, min(Q_b - H_b - R_b, Q_z - H_z - R_z))
```

Stock floors, seasonal availability, protection, work eligibility and output
capacity are **independent** restrictions. A larger quota overrides none of them.
This applies to forage only; `FishStock`'s daily accounting is untouched.

Collection debits **one harvest against two applicable policy limits** — not
duplicate inventory. For `z == b`, that zone's aggregates update once.

## Claims — reserve the complete intended collection
Each owning Job holds at most one pending claim, naming one basin, one
designation, one kind and a remaining quantity. Different kinds need different
jobs. Shared work uses its **coordinator Job** as claim owner (decision 0017);
member Jobs duplicate nothing.

**Uncollected forage is ecological stock, not an `InventoryLot`.** No lots are
fabricated to make inventory reservations represent it.

```
stock_reserved  = sum(remaining_milli of active claims for this basin/patch)
stock_available = max(0, patch.stock_milli - applicable_stock_floor - stock_reserved)
admissible      <= min(available_quota, stock_available)
```

Acceptance preflights and commits quota, stock and output obligations
**atomically, or leaves every quantity unchanged**.

## Midnight
Claims **survive** midnight and consume part of the new day's allowance.
Collection is charged to the day it occurs; hauling already-collected cargo
debits nothing further. Order at the boundary: reset collected totals → preserve
claims → apply seasonal/automatic quota changes → release closure-invalidated
claims and reconcile excess → then admit and collect.

Use the existing offset calendar. **Not `tick % 18000 == 0`** — tick 0 is 06:00
and the first midnight is tick 13500. Annual patch counters reset only at the
year boundary. Load restores saved counters; it is not a synthetic midnight.

## Reconciliation is by whole claims
```
maximum_outstanding_claims = max(0, Q - H)
```
Release **whole claims, newest first** by `(job.created_tick, job.persistent_id)`
descending, until the remainder fits. **A job's promised collection is never
silently shrunk.** A released claim must be reacquired before that job collects.
Releasing a claim generates no WU, XP, cargo or refund.

Collected cargo always survives. Lowering quota below today's collected amount
stops further collection without undoing history. Deleting or rebinding a
designation releases its claims first, and neither resets basin usage.

## Modes and defaults
Basins default to **Automatic**, designations to **Inherit**; **Manual** survives
a season change. Mode IDs compile through the existing catalog conventions — not
a second independent numbering scheme.

```
target_stock_i = floor(800 * K_i / 1000)
allowance_i    = 0 if S_i == 0, else
                 min(K_i - target_stock_i,
                     floor((K_i - target_stock_i) * r_i * S_i / 1000000) + 1000)
automatic_daily_quota = sum(allowance_i over the five kinds)
```

| Season | milli-U/day |
|---|---:|
| Spring | 10720 |
| Summer | 21128 |
| Autumn | 22232 |
| Winter | 6056 |

**All four totals were independently recomputed from §5.5's capacities, regrowth
fractions and seasonal multipliers before acceptance, and match exactly.** The
80% management target is an approved design value; these are **approved starting
values, not validated economy outcomes**. An aggregate allowance does not
guarantee each individual kind holds at 80%.

Manual minimum is zero (no unlimited sentinel). Maximum is `sum(K_i)` =
**1180000 milli-U/day**, also recomputed and confirmed. A designation's larger
manual value cannot expand its basin's allowance. The maximum is a policy
ceiling, not a promise that stock, season, access, storage or labour can supply
it.

## Schema
| Allocation | Layout | Bytes |
|---|---|---:|
| `HarvestZone.harvested_today_milli` | `int64[128]` | 1024 |
| `HarvestZone.quota_reserved_milli` | `int64[128]` | 1024 |
| `HarvestZone.quota_mode` | `byte[128]` | 128 |
| Claim occupancy | `byte[8192]` | 8192 |
| Claim refs and kind | seven `int32[8192]` | 229376 |
| `remaining_milli` | `int64[8192]` | 65536 |
| **Total** | | **305280** |

37 packed bytes per claim row — SoA payload arithmetic, **not** a padded struct
stride or a measured process total. The 1024-byte basin reference from 0026 is
**separate**; together 306304.

`claim_row = owning_job_typed_row` within the existing 8192-Job capacity. **This
is an approved rule, not an inference from matching capacities** — no separate
claim allocator or free heap. Validate the stored Job reference *and generation*
before use; retire a Job's claim before its row is reused.

Authoritative and hashed: claim records, occupancy, daily collected totals, quota
modes and settings. **Outstanding quota totals are derived caches** — maintained
atomically, rebuilt from active claims on load, and excluded from canonical
hashing as duplicate derived state. Do not infer a historical daily total from
`harvested_year_milli`; an older save needs explicit compatibility handling
rather than a silent quota reset.

## Designation preview
A designation binds to the basin containing its **first selected forage tile**.
The preview shows that boundary and visibly excludes outside tiles; confirmation
commits the previewed membership and **never silently clips**. A stale preview is
refused rather than bound to an unrelated basin. One designation grouping several
basins is deferred and needs its own group-quota contract.

## Source
Planner recommendations 1–7, each explicitly approved by Brendan on 2026-09-09,
in response to `chatgpt-prompts/READY_05_planner_rulings.md`. Sixteen acceptance
fixtures (R05-QTEST-01…16) are specified in that handoff and are the required
evidence.
