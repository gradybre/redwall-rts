# Checked reservation total queries

RES-TOTAL-R01 · version 1, draft for review · 2026-09-19

Public-API witness: two items each supply a lot of6e18milli, both reserved by
one job. claim_batch and pool.audit succeed, while job_reserved_total_milli
wraps to-6446744073709551616. Inventory's per-item source totals and per-lot
reserved totals are valid. Do not reject those claims, truncate quantities,
saturate the result, or change save admission to conceal the arithmetic defect.

After SAVE-RES-R01 owner integration, migrate the two query surfaces to the
existing IntMath checked-result convention:
- job_reserved_total_milli(job_ref)->IntMath.IntResult (cold allocating wrapper)
- lot_reserved_total_milli(lot_ref)->IntMath.IntResult (cold allocating wrapper)
- job_reserved_total_milli_into(job_ref,out:IntMath.IntResult)->bool
- lot_reserved_total_milli_into(lot_ref,out:IntMath.IntResult)->bool

Both new into methods use caller-owned output and no new owner field. The old
plain names now return an explicit result, not an integer. Source census finds
only reservation tests calling these public queries; migrate every current
call site to inspect ok before value. Historical evidence/probe source remains
an archived pre-change witness, not runnable current acceptance.

Replace unchecked _sum_list with _sum_list_into. Preserve lookup semantics:
no matching list (including out-of-range or generation-mismatched refs) succeeds
with0. Otherwise traverse the current chain in its existing semantic order,
using IntMath.checked_add_into for each quantity. Success sets out.ok=true,
value=exact total, error empty. Overflow returns false, out.ok=false, value0,
nonempty IntMath error. No partial total is exposed as a success. Null output
returns false without owner mutation. Cold wrappers allocate one result and
use the same implementation. No mutation to canonical/derived fields, pending
scratch or owner math for these public queries.

Existing _audit_lot_totals must consume the checked result and return the
already existing REFUSE_OVERFLOW on overflow, before any equality comparison.
It may use existing _math scratch, consistent with audit's diagnostic role;
no new allocation per lot is required. Other audit blind spots, including
unreferenced Inventory lots, remain the coordinator's separately documented
reconciliation task. Do not claim this fixes all audit coverage.

No changes to claim admission, coalescing, expiry, releases, row allocation,
canonical state, owner schema or wire format. Their release results are row
counts, so they do not need a new quantity-sum bound. This corrects an internal
query API before any production gameplay consumer exists; it does not retire
any user-facing feature.

Tests must cover the real two-item/two-lot witness with overflow refusal, exact
I64_MAX and ordinary sums, empty/missing refs, repeated caller output recovery
(success->overflow->success), both query forms, no owner/scratch/Inventory
mutation, independent cold results, and a structurally valid injected per-lot
overflow proving audit returns REFUSE_OVERFLOW instead of comparing a wrapped
sum. Queries must agree after SAVE-RES-R01 capture/restore. Run existing
reservation suite and relevant save tests, full/static checks, independent
review and exact-head CI. A skipped checked-add mutant must be killed.

Implementation ownership after review: reservations.gd, test_reservations.gd,
a dedicated total-query test file if useful. Serialize after the columns PR;
never dispatch two writers to reservations.gd.
