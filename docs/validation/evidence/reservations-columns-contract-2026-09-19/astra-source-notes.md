# Reservations owner boundary — feasibility notes

2026-09-19 · Astra · planning only; no implementation released.

Next section7 candidate after SAVE-AGE-R01v2. Eight canonical packed columns:
occupancy byte, five i32 columns (job slot/generation, lot slot/generation,
purpose), two i64 columns (quantity,expiry). Fixed row identities must survive;
rows have no generation of their own. Constructor allows bounded row/job/lot
capacities; owner block persists primary rows but no job/lot child extents.

Derived: free minheap, counts, job/lot heads and four intrusive links. Heads and
links are sorted by semantic keys, not row index. Rebuilding by merely appending
ascending rows would be wrong. Existing sorted insertion is worst-case quadratic
at32768rows, so specify a bounded cold-path rebuild and capacity evidence.
No Inventory is bound: it is supplied per mutation. Column installation cannot
call claim_batch/release or change Inventory reserved amounts. Correct world
association, pending Inventory transactions and cross-owner totals require an
explicit adapter/coordinator gate, not an imaginary owner binding.

Source/API and codec both require occupied quantity>0 and expiry>=0; registry
prose incorrectly describes zero quantity as a live empty reservation. Inactive
rows are blanked by both clear and _free_row; codec demands exact blanks.
Purpose remains opaque signed int32. Preserve expired leases until ordinary
expiry handling; do not invent never-expire sentinel.

Owner must reject duplicate(job ref,lot ref,purpose), mixed generations for a
single job or lot slot, out-of-bounds slots under actual constructor capacities,
and overflowing totals before publishing indexes. Existing codec checks fields
but does not prove these cross-row properties. Scratch _math and
_pending_new_rows currently affect only the active call; no persistent diagnostic
exists. Define a separate column refusal instead of altering existing APIs.

Open design work: exact record API/shape, pure validation and deterministic
index rebuild algorithm/memory, reduced-capacity mapping, corruption rejection,
Inventory barrier/busy requirements, source validity vs derived-index checks,
row identity and future allocation/release continuation tests. No full section7
assembly or I1 completion inferred from this owner.


Initial design candidate for independent feasibility review: owner-only Columns
with explicit row/job/lot capacities, eight packed arrays and distinct column
refusal; unique copy/restore names. Keep separate single-block adapter. Owner
has no Inventory binding and must not invent one. Cold boundary/reentry and
cross-owner quiescence remain caller preconditions; supplied-clock barrier is
required by apply. Decide whether the adapter should also require supplied
Inventory for its pure transaction flags, without claiming that proves totals.

A deterministic packed bottom-up merge sort can order occupied row indices by
(job slot,lot slot,lot generation,purpose) and by
(lot slot,job slot,job generation,purpose). Validate same-slot generation
consistency and duplicate keys before constructing sorted links. The actual
source insertion lists use exactly these semantic keys, not row order. Two
row-index work buffers cost8*R; derived outputs cost20*R+4*J+4*L; canonical
columns cost37*R. At maxima these are262144,753664,1212416bytes. These are phase
allocations, not a process peak/RSS claim. Use checked integer totals without
changing owner math scratch. Source capture must define how corrupt derived
indexes/counts are refused; blindly validating only canonical rows may encode a
different future from the malformed live state. Do not silently repair source.

Production callers of claim_batch are currently absent outside the owner itself;
job-reference liveness/typed-row mapping is still integration work. Do not infer
it from the registry's broad directory-generation wording. Existing tests use
plain typed-row/generation pairs. A restoring API must preserve that admitted
structural domain and exact row IDs.
