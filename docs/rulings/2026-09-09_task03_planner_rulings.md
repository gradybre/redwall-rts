# Task 03 — Planner rulings and approved forage quota contracts

| Field | Value |
|---|---|
| Date | 2026-09-09 |
| Project | `/Users/brendan/Developer/redwall-rts` |
| Audience | Claude Code implementation workflow |
| Responds to | `READY_05_three_rulings.md`, citing branch `feat/ecology-rng`, head `90739ef` |
| Scope | Weather selection, deposit representation, basin ownership, and approved forage quota/designation contracts |
| Status | Rulings 1–3 supplied for incorporation into owning specifications; all seven quota/designation recommendations explicitly approved by Brendan on 2026-09-09 |
| Revision | 2 — replaces the earlier open quota section with the approved contracts |

> **Repository note (added by the executor, not the planner).** This file is the
> verbatim planner artifact, stored so the contract lives in the repository
> rather than only in a chat transcript — see
> [decision 0007](../decisions/0007-generated-docs-land-in-repo.md).
> It responds to the **three-ruling** version of the brief at head `90739ef`, so
> it does **not** answer ruling 4 (fishing's two added columns,
> [decision 0027](../decisions/0027-fishing-needs-two-columns-4-2-omits.md)),
> which remains open. Derived records:
> [0026](../decisions/0026-forage-patches-belong-to-the-basin.md) (updated),
> [0028](../decisions/0028-weather-event-selection-mapping.md),
> [0029](../decisions/0029-deposits-are-sixteen-nodes.md),
> [0030](../decisions/0030-forage-quotas-are-daily-and-shared.md).

This document captures the planner's response. Creating this handoff did not edit the repository, implement these changes, run tests, or close implementation gates. The branch and head above identify the incoming brief; verify the current checkout before editing.

Brendan approved recommendations 1–7 individually: daily shared quotas; claim ownership; midnight carryover; cancellation/policy edits; defaults and modes; schema/accounting; and single-basin designation previews. These are now implementation inputs, not questions to ask again. The selected default values remain subject to economy validation; approval is not evidence that those simulations have passed.

## 1. WEATHER selection — adopt the recommended mapping

### 1.1 Algorithm

Use the event order printed in GDD §5.10:

1. Ideal spell.
2. Heavy rain/storm.
3. Drought.
4. Blight.
5. Early frost.
6. Hard freeze.
7. Calm days.

Filter that sequence to rows eligible in the selected season. Retain raw integer weights; do not convert them to rounded percentages.

```text
eligible_rows = season-eligible rows in the fixed order above
weight_sum = sum(row.weight for row in eligible_rows)
roll = uint32_draw mod weight_sum
cumulative = 0

for row in eligible_rows:
    cumulative += row.weight
    if roll < cumulative:
        select row
        stop
```

"Normalized" means relative probability within the eligible set. No numeric percentage normalization is performed.

### 1.2 Exact mapping

All intervals are inclusive.

| Season | Weight sum | Reduced-roll mapping |
|---|---:|---|
| Spring | 85 | Ideal spell 0–29; Heavy rain/storm 30–64; Calm days 65–84 |
| Summer | 120 | Ideal spell 0–29; Drought 30–79; Blight 80–99; Calm days 100–119 |
| Autumn | 135 | Ideal spell 0–29; Heavy rain/storm 30–64; Blight 65–84; Early frost 85–114; Calm days 115–134 |
| Winter | 110 | Ideal spell 0–29; Hard freeze 30–89; Calm days 90–109 |

### 1.3 RNG requirements

| ID | EARS requirement |
|---|---|
| R05-WEATHER-001 | When selecting an event after forced first spring, the system shall consume exactly one WEATHER draw and apply the mapping in §1.2. |
| R05-WEATHER-002 | When scheduling forced first spring, the system shall choose Ideal spell with the existing onset/effects and consume zero WEATHER draws. |
| R05-WEATHER-003 | The system shall use strict `roll < cumulative` comparison and raw integer weights. |
| R05-WEATHER-004 | The system shall retain ARCH-RNG-002 stream initialization and continuation; season index shall order the event and shall not cause per-season reseeding. |
| R05-WEATHER-005 | The system shall disclose the accepted modulo bias and shall not introduce rejection sampling. |

Modulo bias is accepted consistently with the existing RNG contract. The exact mapping is authoritative; no claim of perfectly uniform reduced residues is made.

### 1.4 Required integration and verification

- Amend GDD §5.10 and the WEATHER entry in ARCH-RNG-002 with this mapping.
- Test both sides of every interval boundary and the first/last reduced roll in every season.
- Verify one draw for an ordinary season and zero for forced first spring.
- Verify save/load continuation does not reseed or consume an additional draw.

## 2. Deposit representation — choose Option A

Represent each 4×4 deposit as sixteen independently exhaustible ResourceNode rows. Per-tile depletion is the intended visible behavior.

| Deposit | Inclusive tile footprint | Nodes | Initial quantity per node, milli-U | Capacity per node, milli-U | Total initial quantity, milli-U |
|---|---|---:|---:|---:|---:|
| Stone | `x=44..47, z=70..73` | 16 | 75000 | 75000 | 1200000 |
| Iron | `x=32..35, z=60..63` | 16 | 18750 | 18750 | 300000 |

The existing tile index remains `tile_id = z * 128 + x`.

| ID | EARS requirement |
|---|---|
| R05-DEPOSIT-001 | When generating either deposit, the system shall create its nodes in ascending tile-index order. |
| R05-DEPOSIT-002 | When an ore footprint tile contains a tree node, the system shall replace that node before publishing the ore node, preserving the one-resource-node-per-tile invariant. |
| R05-DEPOSIT-003 | When one deposit node is depleted, the system shall exhaust that node independently of the other fifteen nodes. |
| R05-DEPOSIT-004 | The system shall count these deposits as 32 ResourceNode rows within the existing 4096-row capacity. |

The separately specified renewable bedrock access at `(48,70)` remains separate. This ruling does not change its behavior or include it in either deposit total.

Amend §5.1 to state that a deposit's listed quantity is the sum across its footprint. Do not add a ResourceNode footprint column for this representation.

Verify exact node counts, coordinates, per-node quantities, summed quantities, tree replacement, and independent exhaustion.

## 3. Decision 0026 — confirm basin-owned patches and explicit references

Confirm the explicit basin reference and shared ecological ownership. A player's designation identifies where harvesting is permitted; it does not own a new copy of ecological stock.

### 3.1 Schema and indexing

```text
HarvestZone.basin: EntityRef
ForagePatch.zone: EntityRef referring exclusively to the owning basin
patch_row = basin_typed_slot * 5 + patch_kind
```

Ratify the patch-kind order explicitly:

| Patch kind | Value |
|---|---:|
| Berries | 0 |
| Nuts | 1 |
| Mushrooms | 2 |
| Herb | 3 |
| Roots | 4 |

| Allocation | Arithmetic | Additional packed payload |
|---|---|---:|
| HarvestZone basin slot and generation | `2 * sizeof(int32) * 128` | 1024 bytes |

Basin records count within the existing 128 HarvestZone rows. Preserve the existing 640-row ForagePatch allocation; designations do not receive duplicate active patch sets.

### 3.2 Ownership constraints

| ID | EARS requirement |
|---|---|
| R05-BASIN-001 | The system shall permit stock-owning basin creation only through world generation or an explicit ecology-creation operation. |
| R05-BASIN-002 | When a player draws a harvest designation, the system shall bind it to existing ecological ownership and shall not create a self-owned stock basin. |
| R05-BASIN-003 | When binding a designation, the system shall validate that the binding agrees with the actual harvesting location. |
| R05-BASIN-004 | The system shall reject basin-reference chains and preserve one direct owner for each patch. |
| R05-BASIN-005 | When designations overlap, split, or are deleted, the system shall retain the basin's shared stocks and annual harvest totals without duplication or reset. |

Self-reference alone is not proof that a newly created zone is authorized to own ecological stock. The designation command must not expose the generic stock-creation path.

A stored reference replaces repeated membership lookup; it does not authorize harvesting from an unrelated basin. Geometry still constrains binding.

The single `EntityRef` represents one basin per zone row. The approved initial designation workflow is specified in §4.8: constrain the preview to the basin containing the first selected forage tile. Multi-basin grouping is explicitly deferred; no automatic splitting is selected.

### 3.3 Scope of confirmation

Confirm decision 0026's basin ownership, direct reference, patch sharing, and protection against designation-created stock. **Do not interpret this confirmation as approval of the provisional annual, per-patch quota calculation.** Quota period, scope, and outstanding claims are addressed separately below.

Amend GDD §4.2 and §5.1, decision 0026, the architecture payload ledger, and applicable save/validation schema. Verify overlapping designations debit one patch, deletion/recreation cannot regenerate stock, and invalid binding or chains are refused.

## 4. Forage quotas and designation behavior — approved contracts

### 4.1 Evidence and discrepancy

The incoming brief correctly identifies a schema consequence:

- FishStock contains `harvested_today_milli`.
- ForagePatch contains only `harvested_year_milli`.
- GDD §4.2 types `HarvestZone.quota_milli` without defining its period.
- REQ-SET-069 requires stopping new reservations when quota is reached.
- **UI-SET-050 already labels the selected habitat/zone quota as "units per day."**

The period is therefore not completely unstated across the document set. The UI supports daily intent, while the GDD and forage accounting do not supply the corresponding contract.

The implementation reviewed for this handoff measures quota against each patch's annual total. That introduces both an annual period and a separate allowance per forage kind. Replace that provisional interpretation with the approved daily aggregate contract below.

### 4.2 Decision 1 — daily period and aggregate scope

1. `HarvestZone.quota_milli` limits total forage collected per calendar day across all five kinds.
2. The basin limit is shared across all designations drawing from it.
3. A designation may impose an additional, stricter local limit.
4. `ForagePatch.harvested_year_milli` remains annual ecological/history accounting.

Daily collected totals and outstanding quota totals belong on **HarvestZone**, where both basin and designation limits live. In the formulas below, `Q` is effective daily quota, `H` is collected today, and `R` is outstanding reserved quantity. All quantities are nonnegative int64 milli-U.

```text
available_quota = max(0, min(
    Q_b - H_b - R_b,
    Q_z - H_z - R_z
))
```

Stock floors, seasonal availability, protection, work eligibility and output capacity are independent restrictions. A larger quota overrides none of them. This rule applies to forage; it does not replace FishStock's existing daily accounting or fish-specific quota formula.

For collection of `amount_milli` through designation `z` belonging to basin `b`, atomically:

```text
claim.remaining_milli -= amount_milli
R_b -= amount_milli
H_b += amount_milli
if z != b:
    R_z -= amount_milli
    H_z += amount_milli

patch.stock_milli -= amount_milli
patch.harvested_year_milli += amount_milli
create the corresponding collected cargo exactly once
```

This is one harvest counted against two applicable policy limits, not duplicate inventory creation. For `z == b`, update that zone's aggregates once. Use the existing integer overflow/refusal contract for every authoritative transaction.

| ID | EARS requirement |
|---|---|
| R05-QUOTA-001 | The system shall enforce one daily basin quota across all five forage kinds and all designations bound to that basin. |
| R05-QUOTA-002 | Where a designation has a stricter local quota, the system shall enforce both applicable limits using their respective collected and reserved totals. |
| R05-QUOTA-003 | When a harvest is collected, the system shall convert that amount from reserved to collected and create cargo in one atomic transaction. |
| R05-QUOTA-004 | When designations overlap or are recreated, the system shall preserve the basin's collected totals, outstanding claims, stocks and annual counters. |

### 4.3 Decision 2 — reserve the complete intended collection

Each owning Job has at most one pending forage claim. A claim names one basin, one designation, one forage kind and the remaining quantity. Different forage kinds require separate jobs. Shared work uses its coordinator Job as claim owner; member Jobs do not duplicate claims.

| Event | Required behavior |
|---|---|
| Job acceptance | Atomically reserve quota, harvestable stock and required output capacity for the complete intended collection. |
| Collection | Convert the collected quantity from reserved to harvested and create cargo once. |
| Partial collection | Retain only the uncollected quantity in the claim. |
| Cancellation or lease expiry | Release the uncollected claim and its corresponding outstanding obligations. |
| Worker replacement | Preserve the owning Job's valid claim. |

Uncollected forage is ecological stock, not an InventoryLot. Do not fabricate lots to make inventory reservations represent it. Use the dedicated claim table in §4.7; retain the existing Job-owned output-capacity contract.

For the selected basin/patch, stock available to a **new** claim is bounded by:

```text
stock_reserved = sum(remaining_milli of active claims for this basin/patch)
stock_available = max(0, patch.stock_milli - applicable_stock_floor - stock_reserved)
admissible_quantity <= min(available_quota, stock_available)
```

Availability, protection, consent, destination legality and output capacity must also pass. A claim does not bypass collection-time validation. Any stock-reservation index or cache added to accelerate this query must be budgeted separately; it is not an unlisted allocation inside §4.7's total.

| ID | EARS requirement |
|---|---|
| R05-QUOTA-005 | When accepting forage work, the system shall preflight and commit its complete claim and output obligations atomically, or leave all related quantities unchanged. |
| R05-QUOTA-006 | While a valid claim is outstanding, the system shall include its uncollected quantity in both the applicable quota reservation totals and the basin/patch stock reservation total. |
| R05-QUOTA-007 | When the claim's owning Job is cancelled or its lease expires, the system shall release its uncollected reservations without deleting previously collected cargo. |
| R05-QUOTA-008 | When a worker is replaced on the same valid owning Job, the system shall retain the claim and shall not reserve the same output a second time. |

### 4.4 Decision 3 — claims survive midnight

At the existing offset-calendar midnight, apply the following quota-related order before new admissions or collections:

1. Reset daily collected totals.
2. Preserve outstanding claims and their reservation totals.
3. Apply seasonal availability and automatic quota changes.
4. Release claims invalidated by closure and reconcile claims exceeding a reduced quota using §4.5.
5. Permit new admissions and collections.

Outstanding claims consume part of the new day's allowance. Collection is charged to the calendar day on which it occurs. Hauling already collected cargo consumes no additional quota.

Use the existing clock's calendar crossing. Do not reset on `tick % 18000 == 0`: tick zero begins at 06:00, and the first midnight is tick 13500. Annual patch counters reset only at the existing year boundary. Load restores the saved calendar and counters; it is not a synthetic midnight event.

| ID | EARS requirement |
|---|---|
| R05-QUOTA-009 | When midnight occurs, the system shall reset collected-today totals while retaining valid outstanding claims. |
| R05-QUOTA-010 | When an automatic quota changes or a patch closes at a seasonal boundary, the system shall reconcile affected claims before admitting or collecting further forage. |
| R05-QUOTA-011 | When midnight occurs, the system shall not renew or extend a Job lease merely because its claim crossed the boundary. |
| R05-QUOTA-012 | When already collected cargo is hauled, the system shall not debit quota again. |

### 4.5 Decision 4 — quota cuts and designation edits

For a new effective quota `Q` and existing collected total `H`:

```text
maximum_outstanding_claims = max(0, Q - H)
```

If outstanding claims exceed that allowance, release **whole claims**, newest first by `(job.created_tick, job.persistent_id)` descending, until the remaining claims fit. Do not silently shrink a job's promised collection. A released claim must be reacquired before its job can collect.

The ordering uses the owning Job's existing fields, including the coordinator for shared work; no separate claim creation timestamp is introduced. Reconciliation considers both applicable limits. For changes affecting multiple zones, apply the same total claim order and release a claim when its applicable basin or designation remains over its allowed outstanding total. Claims already released are not processed twice.

- Collected cargo is preserved.
- Lowering quota below today's collected amount stops further collection; it does not undo prior harvest history.
- Setting quota to zero releases all outstanding forage claims affected by that zero limit.
- Deleting or rebinding a designation releases its outstanding claims before changing its identity or basin.
- Neither deletion nor rebinding resets basin usage.
- Releasing a claim does not itself generate productive WU, XP, cargo or an additional refund. Retain the existing job/WIP lifecycle rules.

| ID | EARS requirement |
|---|---|
| R05-QUOTA-013 | When a quota reduction leaves excessive outstanding reservations, the system shall release whole claims in the specified newest-first order until both applicable limits are satisfied. |
| R05-QUOTA-014 | When a claim is released by reconciliation, the system shall prevent further collection under that claim until the owning Job reacquires valid reservations. |
| R05-QUOTA-015 | When the player previews a quota reduction, the UI shall show the number of affected jobs before the change is applied. |
| R05-QUOTA-016 | When a designation is deleted or rebound, the system shall release its outstanding claims first and preserve collected cargo and the basin's accounting. |

### 4.6 Decision 5 — automatic seasonal defaults and manual overrides

| Mode | Valid use | Behavior |
|---|---|---|
| Automatic | Basin | Recompute the seasonal quota from the formula below. |
| Inherit | Designation | Use its basin's effective daily quota as the designation limit. |
| Manual | Basin or designation | Use the player's finite daily value. |

Default basins to Automatic and designations to Inherit. Preserve a manual setting when the season changes. An inherited limit follows the basin's effective quota; reductions are reconciled under §4.5. Compile mode IDs through the existing catalog conventions rather than introducing a second independent enum numbering scheme.

For each forage kind `i`, let `K_i` be capacity in milli-U, `r_i` be its published daily regrowth fraction per 1000, and `S_i` be its published seasonal multiplier per 1000:

```text
target_stock_i = floor(800 * K_i / 1000)

allowance_i = 0 if S_i == 0
otherwise:
    allowance_i = min(
        K_i - target_stock_i,
        floor((K_i - target_stock_i) * r_i * S_i / 1000000) + 1000
    )

automatic_daily_quota = sum(allowance_i for all five forage kinds)
```

This policy uses an **80% stock management target** and the existing additive 1-U regrowth term. It does not substitute current stock for `target_stock_i`. Current stock and its floor still constrain actual reservations independently.

| Season | Automatic quota per basin, milli-U/day | U/day |
|---|---:|---:|
| Spring | 10720 | 10.720 |
| Summer | 21128 | 21.128 |
| Autumn | 22232 | 22.232 |
| Winter | 6056 | 6.056 |

The 80% target is an approved design choice. The totals are derived from the existing capacities/rates/seasonal multipliers. These are approved starting values for implementation, **not validated economy outcomes**. An aggregate allowance does not guarantee each individual kind remains at 80% stock.

Manual settings:

- Minimum is zero: no new harvesting, with existing claims reconciled by §4.5.
- No unlimited sentinel is supported.
- Maximum is `sum(K_i)` across the basin's five patches: currently **1180000 milli-U/day**.
- A designation's larger manual setting cannot expand its basin's allowance; the available-quota formula enforces both.
- The maximum is a policy ceiling, not a guarantee that stock, season, access, storage or labor can supply it.

| ID | EARS requirement |
|---|---|
| R05-QUOTA-017 | When creating a basin, the system shall default its quota mode to Automatic and calculate the current season's quota using the formula above. |
| R05-QUOTA-018 | When creating a player designation, the system shall default its quota mode to Inherit. |
| R05-QUOTA-019 | When the season changes, the system shall update Automatic and inherited limits without overwriting Manual settings. |
| R05-QUOTA-020 | When a manual quota is supplied, the system shall accept only finite values from zero through the basin's combined patch capacity, inclusive. |

### 4.7 Decision 6 — packed schema and save accounting

| Allocation | Layout | Additional bytes |
|---|---|---:|
| HarvestZone daily collected | `harvested_today_milli: int64[128]` | 1024 |
| HarvestZone outstanding quota total | `quota_reserved_milli: int64[128]` | 1024 |
| HarvestZone quota mode | `quota_mode: byte[128]` | 128 |
| Forage claim occupancy | `active: byte[8192]` | 8192 |
| Forage claim references and kind | Seven `int32[8192]` columns: Job slot/generation, designation slot/generation, basin slot/generation, patch kind | 229376 |
| Forage claim quantity | `remaining_milli: int64[8192]` | 65536 |
| **Total for the approved quota additions** | `2048 + 128 + 8192 + 229376 + 65536` | **305280** |

Each claim's logical payload is:

```text
active: byte
job: EntityRef
designation: EntityRef
basin: EntityRef
patch_kind: int32
remaining_milli: int64
```

That is 37 packed bytes per row. This is SoA payload arithmetic, not a padded struct stride or measured process-memory total.

**Explicit indexing decision:** `claim_row = owning_job_typed_row`, within the existing 8192-Job capacity. No separate claim allocator or free heap is required. Validate the stored Job reference and generation against the directory before use. Retire/release a Job's active claim before its row can be reused. This indexing is an approved rule, not an inference from matching capacities.

The already-approved **1024-byte basin reference in §3.1 is separate**. Together these two additions total **306304 packed bytes**. Existing fields such as `quota_milli`, annual patch counters and Job lease state are not added again. Count any additional implementation buffers explicitly rather than hiding them in this payload total.

| State | Save/hash treatment |
|---|---|
| Active claim records and occupancy | Authoritative; save and hash. |
| Daily collected totals | Authoritative; save and hash. |
| Quota modes and settings | Authoritative; save and hash. |
| Annual patch totals | Retain existing authoritative save/hash treatment. |
| Outstanding quota totals | Derived caches; maintain atomically and rebuild from active claims on load; exclude as duplicate derived state from canonical hashing. |

For each zone, reconstruct its outstanding total by summing active claims for which it is the basin or designation, counting a claim once when those references are identical. Reconstruct basin/patch reserved stock from the same claims. Validate references, positive active quantities, patch kinds, owner indexing, shared ownership and applicable accounting before exposing the loaded world.

Integrate these additions through the existing versioned save contract. Do not infer a historical daily total from `harvested_year_milli`; an older format without sufficient history requires explicit compatibility handling rather than a silent quota reset.

| ID | EARS requirement |
|---|---|
| R05-QUOTA-021 | The system shall store forage claims in fixed packed columns indexed by owning Job typed row and shall not allocate a per-claim object. |
| R05-QUOTA-022 | When loading a world, the system shall restore authoritative claim and quota state and rebuild reservation aggregates before admissions or collections resume. |
| R05-QUOTA-023 | When a Job row is retired or reused, the system shall prevent any prior generation's forage claim from remaining active. |
| R05-QUOTA-024 | When reporting allocation totals, the system documentation shall distinguish the 305280-byte quota payload, the separate basin reference, and any additional measured or planned overhead. |

### 4.8 Decision 7 — single-basin designation preview

For the initial implementation, constrain a designation to the basin containing its **first selected forage tile**. Display that basin boundary and excluded tiles while the player draws. Do not silently alter the selected region after confirmation.

The player may draw a separate designation in a neighboring basin. One visible designation grouping multiple basin-specific rows is a later extension requiring its own group-quota contract; it is not part of task 03's approved implementation.

| ID | EARS requirement |
|---|---|
| R05-DESIGNATION-001 | When the first forage tile is selected, the designation preview shall bind to that tile's existing basin. |
| R05-DESIGNATION-002 | While the player draws, the preview shall show the bound basin boundary and visibly exclude tiles outside it. |
| R05-DESIGNATION-003 | When confirming a designation, the system shall commit the valid previewed membership without silently clipping additional tiles after confirmation. |
| R05-DESIGNATION-004 | Where previewed membership or binding is no longer valid at commit, the system shall refuse the stale operation and require an updated preview rather than binding an unrelated basin. |

### 4.9 Required acceptance evidence

All amounts below are synthetic test inputs, not additional balance defaults.

| ID | Fixture | Required observation |
|---|---|---|
| R05-QTEST-01 Aggregate kinds | Basin Q=10000; collect berries=4000, then nuts=3000 through eligible designations; no outstanding claims remain. | Shared basin H=7000; remaining basin allowance=3000, not a separate 10000 for each kind. |
| R05-QTEST-02 Overlap | Two designations share a basin with Q=10000; first reserves 6000; second attempts 5000. | Second complete reservation is refused atomically; remaining basin allowance is 4000. |
| R05-QTEST-03 Local limit | Basin Q=10000; designation Q=3000; designation has H=1000 and R=500; no other basin usage. | Available quota through that designation is 1500. |
| R05-QTEST-04 Midnight | Q=10000, H=4000, R=3000 immediately before midnight; no closure or quota change. | After midnight H=0, R=3000, available quota=7000; collecting 2000 gives H=2000, R=1000 and available quota remains 7000. |
| R05-QTEST-05 Quota cut | H=2000, active claims oldest=3000 and newest=4000; reduce Q to 6000. | Allowed R=4000; release the newest whole claim; retain R=3000; available quota=1000. |
| R05-QTEST-06 Below-used cut | H=5000 and R=1000; reduce Q to 2000. | H remains 5000; all affected outstanding claims release; availability is zero; collected cargo persists. |
| R05-QTEST-07 Partial collection | Claim=6000; collect 2000. | Claim and applicable R decline to 4000; applicable H and patch annual total rise by 2000; stock falls and cargo rises by 2000 once. |
| R05-QTEST-08 Replacement and cancellation | Replace a member on a valid owning Job, then cancel that Job. | Replacement preserves its claim; cancellation releases only uncollected obligations. |
| R05-QTEST-09 Deletion/recreation | Collect through a designation, delete it, then draw another over the same basin. | Basin H and patch annual total persist; new designation cannot create stock or bypass the remaining basin allowance. |
| R05-QTEST-10 Boundary reduction/closure | Outstanding claims cross a season boundary into lower automatic quota or zero availability for their kind. | Boundary processing preserves valid claims, releases invalid/excess claims deterministically, and admits no intervening collection. |
| R05-QTEST-11 Defaults | Evaluate all five patch allowances for all four seasons using the existing catalog. | Totals equal 10720, 21128, 22232 and 6056 milli-U/day; manual values survive a season change. |
| R05-QTEST-12 Save/load | Save with partial collection, overlapping designations, manual settings and active claims; resume in an independent process. | Same canonical authoritative state and subsequent claim/cargo outcomes; aggregates rebuild identically; no synthetic daily reset. |
| R05-QTEST-13 Stale identity | Retire and reuse an owning Job row. | An old-generation claim cannot act on the replacement Job. |
| R05-QTEST-14 Preview | Drag from the first forage tile across a basin boundary. | Preview shows excluded tiles; confirmation creates one basin-bound designation with the previewed valid membership. |
| R05-QTEST-15 Atomic refusal | Fail stock, quota or output-capacity preflight independently. | No partial quota claim, stock obligation, output reservation, stock debit or cargo creation survives. |
| R05-QTEST-16 Packed payload | Derive allocation sizes from actual fixed columns. | Claim payload is 303104 bytes; the specified quota additions total 305280 bytes; extra implementation allocations are separately visible. |

Run stock-conservation and replay checks alongside these fixtures. Validate the starting quota values in the existing economy scenarios before describing them as balanced. If a fixture needs an unfinished owning subsystem, report that dependency and the unexecuted evidence rather than claiming a pass.

## 5. Implementation handoff

1. Verify the current branch and preserve unrelated work.
2. Incorporate rulings 1–3 and all seven approved contracts in §4 into their owning GDD/architecture/UI sections and decision records before relying on this handoff as the only contract.
3. Implement and validate weather selection and per-tile deposit generation.
4. Reconcile the provisional basin implementation with the ownership constraints in §3; confirmation does not authorize stock creation from player designation.
5. Replace the provisional annual per-patch quota enforcement with the approved daily aggregate policy, claims, midnight rules and deterministic reconciliation. Budget and integrate the save schema as specified.
6. Implement the approved automatic/manual/inherited policy controls and single-basin designation preview when their command/UI dependencies are available. Do not ask for approval again on the seven accepted choices.
7. Run the acceptance fixtures in §4.9 and the relevant existing suites; report actual results and dependencies that prevent execution.
8. Update task 03's checklist to distinguish implemented behavior, verified behavior, and outstanding dependencies.
9. Report changed files, actual test results, remaining unsatisfied requirements, and any additional schema or numerical decisions encountered.

The seven quota/designation decisions are closed by user approval. Implementation, save compatibility work, economy validation and dependent command/UI integration are still work to perform. Weather and deposit work may proceed independently. This document does not close unrelated gaps listed in `forage.gd`, performance qualification, or movement engineering gates.

## 6. Provenance

| Content | Origin |
|---|---|
| Event weights, eligibility, forced first spring, deposit footprints and total quantities | Existing GDD |
| RNG stream continuation and modulo discipline | Existing architecture |
| Weather row mapping and interpretation of normalization | Planner ruling in this handoff |
| Per-tile deposit representation and independent exhaustion | Planner ruling; quantities derived exactly from existing totals |
| Basin reference and direct-owner implementation | Executor's provisional decision 0026, confirmed with constraints here |
| Explicit patch indexing/order | Ratified here; not inferred solely from capacity ratios |
| Daily wording | Existing UI-SET-050 |
| Daily aggregate forage policy, claim lifecycle, midnight carryover and cancellation order | Planner recommendations explicitly approved by Brendan, 2026-09-09 |
| Automatic/Manual/Inherit modes, zero/no-unlimited behavior and manual maximum | Planner recommendations explicitly approved by Brendan, 2026-09-09 |
| 80% management target | New planner-originated design value, explicitly approved; economy validation pending |
| Seasonal default totals and 1180000 milli-U manual ceiling | Derived from the approved policy and existing ecology catalog; not measured economy outcomes |
| Job-indexed forage claim table and quota columns | Planner schema recommendation explicitly approved; 305280 bytes derived from packed field widths and existing capacities |
| 1024-byte basin-reference addition | Derived packed-column arithmetic, separate from the quota additions |
| Single-basin preview behavior and deferred grouping | Planner recommendation explicitly approved by Brendan, 2026-09-09 |
| Acceptance fixture quantities | Synthetic validation inputs authored for these contracts; not game balance values |

The `R05-*` requirement identifiers are local handoff identifiers. Map them into the repository's requirement/decision conventions without renumbering unrelated requirements.
