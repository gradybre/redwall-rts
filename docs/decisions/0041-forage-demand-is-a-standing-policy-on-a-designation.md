# 0041 — Forage demand is a standing policy on a designation, not a service and not a cycle
Date: 2026-09-10 · Status: Accepted

## Decision

`scripts/core/job_planner.gd` gains R06-JOB-001/002's repeat forage harvest
producer. It is the third producer in that module and the first with a **second
owner class**, so it gets its own table:

```text
demand_row(designation typed row z, kind k) = z * PATCH_KIND_COUNT + k
ZONE_OWNER_CAPACITY = 128    PATCH_KIND_COUNT = 5    DEMAND_ROW_COUNT = 640
OPERATION_FORAGE_HARVEST = 2      is_daily_service_operation(2) == false
```

Seven things are settled here.

1. **The owner class is HarvestZone, so the table is separate.** The
   pending-service table is owner-major over 4096 FarmPlot rows; forcing 128
   designations into it would reserve 4096 rows for 128 owners. The demand table
   uses the same stride `forage.gd`'s own ForagePatch block uses, forced by the
   same two stated numbers.
2. **Repeat demand is neither a daily service nor a one-shot cycle.** It has no
   third identity term — no service day, because it does not reopen daily, and no
   field cycle, because it never finishes. Its identity is
   `(designation EntityRef, kind)` and its lifetime is the player's enablement.
   `is_daily_service_operation()` is the seam that keeps it out of midnight's
   machinery, and `_init()` asserts the predicate answers false for it.
3. **"World-generation basin creation alone shall create no harvest demand" is
   structural.** The enablement gate requires `forage.is_designation()`, which is
   true only for a zone bound to *another* zone's basin.
4. **"Shall not reserve the same available quantity twice" is decision 0030's
   quota accounting, not a second reservation concept.**
5. **The `dangerous` flag is derived from the designation's own `danger` band**,
   at bind time and on every reconciliation of a live harvest. The consent
   *check* is not duplicated here.
6. **Output space and legal access have no owning store** and are declared on the
   Job as `inputs_gate = GATE_UNAVAILABLE`, which refuses at selection.
7. **13312 bytes** of new packed payload are added to `systems_architecture.md`
   §2.2 with every dependent total in §2.3 recomputed.

## Why

**A separate table, because the owner class is different — and the operation
ordinal is still shared.** `service_row()` addresses FarmPlot rows and
`is_operation()` says so. `OPERATION_FORAGE_HARVEST = 2` is *not* addressable
there, but `is_daily_service_operation()` answers for it, and it answers **false**
because the daily operations occupy the low ordinals. That is deliberately the
existing seam rather than a parallel one: `_settle_preceding_day()` and
`preceding_day_is_settled()` already consult that predicate, so midnight walks the
FarmPlot table and never touches a demand row. Widening `OPERATION_COUNT` to 3
instead would have cost 4096 unused rows per column for a 128-row owner class.

**Enablement is the whole of R06-JOB-001, and the basin gate is the whole of its
second sentence.** `forage.create_zone()` makes a new zone its own basin, so
"bound to an existing basin" is exactly `forage.is_designation()` — true only
after `forage.set_basin()` has pointed the zone at another zone's stock. A
generated basin fails that gate, which is decision 0026's R05-BASIN-002
anti-multiplication principle showing up one layer higher. Naming it that way
matters: the alternative reading, "any FORAGE zone with patches", would have let
world generation produce harvest demand by existing, and no check placed *later*
could have been trusted not to be forgotten.

**The double-reservation rule needed no new mechanism, and adding one would have
broken it.** Decision 0030 already counts an outstanding claim inside the zone's
`quota_reserved_milli` and its patch's `stock_reserved`, so
`available_quota_milli()` and `stock_available_milli()` have subtracted it before
the producer ever asks. The producer asks for
`min(available_quota, stock_available)` and gets **zero** when another Job holds
it — including when that Job belongs to a *different* designation over the *same*
basin, which is the case the sharing rule exists for. A second reservation store
would have double-counted or drifted. The claim table is Job-indexed with one
claim per Job, so the Job must be created before the quota can be reserved; every
failure after that point releases the claim and destroys the Job, and a named
test compares eight quantities before and after twenty refusals.

**One outstanding harvest per (designation, kind) is an interpretation, and it is
recorded as one.** The ruling says "repeat demand" and gives no concurrency
number. Decision 0030 gives one claim per Job naming one kind, and the ruling's
acceptance list requires that repeated enable/dirty events create no duplicate
claim. A bound of one per pair is what makes the table a table; an unbounded
number would be the hidden queue R06-JOB-008 forbids. Its cost is visible: the
five kinds are reconciled in §5.5's own table order against an **aggregate** daily
quota, so an early kind's claim leaves less for a later one. That order is
deterministic and stated. **No fair-share policy is invented**, because none is
specified; if one is wanted it is a change to that order and to nothing else.

**The work total is evaluated at FORAGE level 0, and that is an interpretation
too.** §5.5's `work_per_u` depends on the *worker's* level, and no worker is bound
when a Job is created — §5.3 binds one later. Level 0 is the only level readable
at creation and also the **largest** total the formula produces, so no harvest is
ever under-quantified. The alternative, an assumed average level, would have been
an invented constant. A skilled worker's discount needs a work-recomputation seam
at assignment; ARCH-SYS-011/012 owns that and does not exist. Mushrooms cannot
distinguish level 0 from level 1 (both round to 5 WU/U), so the named test uses
**herb at natural danger 1**, where the two levels are 8 and 7.

**The danger flag is derived because the architecture says it must be.** §2.2:
the flag's "owning sources are HarvestZone `danger` and FishHabitat `danger` …
until those stores exist the flag is set explicitly by whoever creates the job,
and it SHALL be recomputed from the owning zone/habitat danger value when the
job's source or destination is bound and whenever that danger value changes."
HarvestZone exists, so this producer takes no `dangerous` argument at all. The
band read is the **designation's own**: `forage.gd`'s header separates the basin's
natural danger, which §5.5's work formula uses, from the harvesting zone's hazard
band, which REQ-SET-067 gates on. Storing consent stays `priorities.gd`'s and
checking it stays job eligibility's; what this module owes that check is a flag
that is derived rather than asserted.

**Disabling retains outstanding work.** Nothing in the ruling or decision 0030
withdraws an accepted claim on a disable, and `forage.set_zone_enabled(false)`
releases none either; `collect_claim()` re-checks the designation, so a disabled
source stops collecting without this module inventing a cancellation rule.
Deleting or rebinding a designation *is* specified to release its claims, and
`forage.gd` does that; `_release_abandoned_demand()` is this module's half and it
cancels the orphaned Job.

**Retained UNMET demand is re-derived, not accumulated.** A row marked UNMET means
"job capacity refused this, last time". It is dropped at the start of the next
reconciliation so the gates decide again, and rewritten only if capacity refuses
again. Leaving it standing reported a capacity blocker on a row whose real
obstacle had since become the quota — found by a failing test, not by review.

## Gates evaluated, and gates deferred with their blocking store

| R06-JOB-001/002 gate | Owner | Treatment |
|---|---|---|
| FORAGE zone type | `forage.zone_type_of()` | **Evaluated.** `ZONE_TYPE_MISMATCH` |
| `enabled` flag | `forage.is_zone_enabled()` | **Evaluated.** `ZONE_DISABLED` |
| `protected` flag | `forage.is_zone_protected()` | **Evaluated.** `ZONE_PROTECTED` |
| Bound to an existing basin | `forage.is_designation()` + `basin_slot_of()` | **Evaluated.** `ZONE_IS_NOT_A_DESIGNATION`, `BASIN_NOT_PRESENT` |
| Shared daily quota | `forage.available_quota_milli()` | **Evaluated** (decision 0030) |
| Stock floor and reservation capacity | `forage.stock_available_milli()` | **Evaluated** (REQ-SET-066's sustainable floor) |
| Seasonal availability | `forage.availability_per_1000()` | **Evaluated.** `PATCH_DORMANT` |
| Patch existence | `forage.patch_row_for_zone()` | **Evaluated.** `PATCH_NOT_PRESENT` |
| Job capacity | `entity_directory.gd` | **Evaluated.** Retained as UNMET with the store's own code |
| Danger consent | `priorities.gd` + job eligibility | **Not checked here.** The flag it reads is derived here |
| **Output space** | *none* — no Job/container binding exists (R05-QTEST-15) | Declared `inputs_gate = GATE_UNAVAILABLE`; refuses at selection |
| **Legal access** | *none* — no reachability oracle, eligibility step 7 absent | **Not evaluated and not faked.** Named as an open gate |
| **Intensive harvest policy** | *none* — `FishHabitat.intensive_harvest` is fishing's | Always the sustainable 20% floor; the 5% floor is never claimed |
| **Resident priorities / schedule** | `priorities.gd`, `schedule.gd` via `jobs.evaluate()` | Not bypassed: the producer writes a Job and selection applies them |

## Consequences

- **`enable_forage_demand()` and `disable_forage_demand()` exist and nothing calls
  them.** Blocker U2 stands: ARCH-CMD-003's command kinds are unimplemented, so
  R06-JOB-001's "when a player confirms or enables" has no transport. **No command
  kind is invented and ARCH-CMD-003 is not renumbered**; the ruling's
  implementation boundary directs that at the existing `DESIGNATE_ZONE`,
  `SET_POLICY` and `SET_FIELD_ROTATION` payloads, which is a change to a document
  this work does not own.
- **A published harvest can never be selected in this build**, because its inputs
  gate is `GATE_UNAVAILABLE`. That is the honest state of a settlement with no
  output binding, and it is the same state decisions 0039 and 0040 left a tending
  service needing water and a sowing job needing seed.
- **Nothing writes `JOB_STATE_WORK`.** A published harvest is QUEUED. The module's
  only other state write is CANCELLED, on a harvest whose designation vanished.
- **Nothing collects.** `forage.collect_claim()` is the transaction that debits
  stock and yields an amount to make cargo from; ARCH-SYS-006 (increment 10) is
  its driver and does not exist. A settled harvest releases whatever its claim
  still holds and creates no cargo.
- **`forage.gd` is untouched.** No column, refusal or contract in it was changed;
  the producer composes its published readers.
- **`OrderMode` is untouched.** No designation or basin id is written into a
  `recipe_id` and no `ProductionOrder` is created: the ruling calls the ecology
  workflow "repeat demand under its own policy", and that is what this is.
- **R06-JOB-003 still needs `Expedition`; R06-JOB-005 still needs `FieldPolicy`;
  R06-JOB-006 still needs `Hive`.** Nothing here rotates a forage kind either: the
  §5.5 order is fixed, not a policy.
- **Two refusal branches in `_forage_quantity()` are unreachable** through the
  module's own gate order — the patch is already known present and the season
  already known valid. They are kept for the same reason `forage.gd` keeps its
  malformed `P > K` guard (a save path is coming) and are named in the module
  header rather than deleted or pretended to be covered.
- **`_refresh_dangerous()` has no production trigger.** `forage.gd` publishes no
  setter for `HarvestZone.danger` ("fixed at generation"), so the architecture's
  "whenever that danger value changes" half cannot fire in the running build. It
  is exercised through a test subclass, exactly as `forage.gd`'s malformed-stock
  guard is.
- One existing test changed behaviour and was **strengthened, not weakened**:
  `test_the_day_boundary_marks_designations_for_the_new_days_allowance` — written
  in this same change — first asserted only that a designation was dirty after
  midnight, which was already true from the enable. It now drains the dirty set
  first. No pre-existing test was modified.

## Four defects the mutation run found

Every one was a missing test, and each is now named:

1. **A live harvest reported an empty ecology.** Dropping the pending guard from
   `_settle_pending_harvest()` survived, because after a successful claim
   `min(quota, stock)` is *always* zero — so no second Job could be published
   either way and only the **refusal code** differed. A caller cannot act on
   "already pending" and "nothing harvestable" the same way. Now asserted.
2. **A stale claim could be silently overwritten.** Ignoring `claim_forage()`'s
   refusal survived, because no gate in the producer can make a claim fail. One
   path outside it can: a Job destroyed without releasing its claim leaves the
   row active, and the next Job on that reused row is refused with
   `CLAIM_STALE_JOB`. Overwriting it would be *literally* the double reservation
   R06-JOB-002 forbids. Now a named test.
3. **Midnight releasing quota was untested.** Removing `mark_all_zones_dirty()`
   from `run_day_boundary()` survived because the assertion ran against a
   designation the *enable* had already marked dirty.
4. **The demand stride was untested across a zone boundary.** A stride of 4
   survived every readback test, because the readers were consistently wrong
   together. It collides one designation's ROOTS row with the next designation's
   BERRIES row — now exercised with two adjacent designations in summer, when
   both kinds are available.

## The byte cost, and the older discrepancy it does not touch

| Column group | Rows | Bytes |
|---|---:|---:|
| `ForageDemand.enabled` B8 | 128 | 128 |
| `ForageDemand.owner_slot, owner_generation` I32 ×2 | 128 | 1024 |
| `ForageDemand.status, blocker` B8 ×2 | 640 | 1280 |
| `ForageDemand.job_slot, job_generation` I32 ×2 | 640 | 5120 |
| `ForageDemand.quantified_milli` I64 | 640 | 5120 |
| `ForageDemand.dirty.dirty_zone` I32 | 128 | 512 |
| `ForageDemand.dirty.is_zone_dirty` B8 | 128 | 128 |
| **Total** | | **13312** |

The seven scalar counters (`_demand_enabled_count`, `_demand_pending_count`,
`_demand_unmet_count`, `_forage_created_count`, `_forage_completed_count`,
`_forage_cancelled_count`, `_forage_claimed_milli`) are module scalars, not
columns, and are outside the field payload for the same reason decisions 0039 and
0040 keep theirs outside. **No claim, quota or reservation storage is added**:
decision 0030's 305280-byte claim payload and 131072-byte ordering cache are
unchanged, because the producer adds no second reservation concept.

Dependent totals, each recomputed rather than restated:

| Figure | Before | After |
|---|---:|---:|
| §2.2 fixed-field payload sum | 24501202 | 24514514 |
| §2.3 fixed registry payload | 24938834 | 24952146 |
| Planned allocated payload | 59291342 | 59304654 |
| One live world plus reserve | 67679950 | 67693262 |
| Headroom below decimal 100 MB | 32320050 | 32306738 |
| Additional candidate mutable state | 53075758 | 53088558 |
| Transactional peak plus same reserve | 120755708 | 120781308 |
| Transactional headroom | −20755708 | −20781308 |

**The 437632-byte discrepancy decisions 0039 and 0040 recorded is still there and
is still not corrected here.** Measured again on this checkout: §2.2's own
`Payload bytes` column sums to **24952146**, which is exactly the ledger's *Fixed
registry payload* row, while §2.2's prose sentence states **24514514** — 437632
lower. Removing this decision's +13312 reproduces the identical gap against the
previous figures, so the discrepancy predates this change and the +13312 is
applied consistently to both sides of it. It is left for whoever owns that
arithmetic; guessing which figure is authoritative would overwrite another
decision's work.

## Source

- `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1 — R06-JOB-001,
  R06-JOB-002, R06-JOB-008, the lifecycle/ordering paragraph, the defaults
  paragraph (priority 3), the OrderMode paragraph and the implementation
  boundary. Adopted by Brendan as a whole.
- Decision 0030 — the daily aggregate quota, the claim contract, and the
  `min(available_quota, stock_available)` admissibility bound this producer asks
  for rather than recomputes.
- Decision 0026 — R05-BASIN-001/002, the anti-multiplication principle the basin
  gate applies at the producer layer.
- GDD §4.2 (HarvestZone, ForagePatch and Job rows), §4.3
  (ZoneType/JobKind/JobState/Season), §5.1 (the offset calendar and basin
  sharing), §5.5 (the forage table, work formula, floors and danger),
  REQ-SET-066, REQ-SET-067, REQ-SET-069.
- `docs/systems_architecture.md` ARCH-SYS-009, ARCH-MEM-001, ARCH-MEM-005,
  ARCH-MEM-009, §2.2 (including the dangerous-work flag paragraph), §2.3.
- Decisions 0015 (`_into` readers), 0017 (coordinator Job), 0022
  (`required_skill`), 0023 (gate semantics), 0024 (allocate-before-consume),
  0039 (the pending-service identity) and 0040 (the sowing identity this extends).
