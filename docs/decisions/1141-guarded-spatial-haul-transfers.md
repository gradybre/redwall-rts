# 1141 — Guarded spatial haul transfers
Date: 2026-10-04 · Status: Accepted lower-owner component; Delivery composition pending

## Decision

Spatial hauling uses one original Inventory journal for admission, loading,
reposting carried goods, unloading, or cancellation. The final actual Delivery
observation runs with Inventory's existing attestation barrier raised. Direct
original-scope, claim, packet and staged-goods checks follow that observation;
only an infallible pool/caller publication tail follows a successful commit.
The inherited flat hauling doors retain their behavior.

`haul_transfer_contract.gd` is cycle-free and refuses by default. Its reusable
`Transfer` carries eight full references and nineteen integer scalars: 216
logical bytes. References are Job, worker, original lot/container, destination,
original satchel, arriving lot and staged satchel. Scalars are action, claim
row/count, original/final purpose, quantity, expiry, original reserved grams,
carry limit, item/mass/quality/age/remainder/provenance/recipe, original source
quantity/reservation and original destination reservation. The pool retains an
original packet and exposes a separate matching callback view. There is no new
per-Job map, quantity ledger, work counter, claim epoch or inventory snapshot.

LOAD's satchel exists in the staged Inventory before the Resident points to it.
UNLOAD can retire that same satchel before its pointer clears. The final Delivery
proof must attest those expected staged facts, actual arrival, current full
Job/worker/source/destination identities and completed handling; ordinary live
cargo queries cannot substitute. Reposting moves no goods but uses the same
last-observer boundary. Cancellation releases claims and destination grams in
the same journal and preserves carried goods. It does not require a live
connector Project or a still-assigned worker and grants no movement or work.

Admission likewise stages capacity and source reservation together, then
publishes the existing Pool and Planner rows after its guarded commit. It cannot
use the legacy reserve-then-claim sequence with a later compensating release.

## Ownership and budget

This packet owns only Inventory, Reservations, the new protocol and dedicated
tests/evidence. The concurrent 1140 lane owns Delivery, HaulPlanner and Work.
HaulCarry, Routes and all profile consumers remain frozen. Delivery must use
prevalidated direct Resident/Planner/Job publication after success, rather than
an observing HaulCarry tail. No transfer callback may mutate or replace original
Pool rows; public teardown/restore doors also obey the synchronous scope.

The approved new reservation is 3,072 bytes: 512 fixed logical bytes (two
216-byte packets and one active boolean currently account for 433), 512 numeric
helper bytes and 2,048 provisional native/reference/result bytes. Delivery's
separate 4,096-byte allowance borrows the packet rather than counting another
copy. Final source-derived simultaneous chains must establish those limits;
the reservation is not measured native-memory qualification. Existing journal
and claim banks are reused and no capacity or total gate increases.

## Evidence required

Exercise actual full and partial load/unload, already-carried repost, expired or
missing claims, capacity/journal refusal, foreign full generations and owners,
late provider mutation, packet mutation, recursive transfer, attempted commit/
abort and Pool clear/restore/metadata mutation. Refusals preserve Inventory and
Pool bytes, allocator state, claims and grams; valid retries succeed once.
Cancellation covers absent claims and released workers while preserving goods.
Shared tests and the composed 1140 caller remain distinct acceptance gates.

## Source

ARCH-JOB-001, ADR 1021–1023; the Inventory-owned final input/settlement barriers
from 1117, 1118 and 1120; root's explicit 1141 ownership and 3,072-byte approval.
This contract invents no load rate, movement capability, set-down source or
production profile permission.

## Implementation candidate

The three production files and dedicated test are frozen under
`docs/validation/evidence/guarded-spatial-haul-2026-10-04/source-review-3/`.
The actual fixed census is 433/512; the largest numeric/helper chain is 466/512
including conservative OpResult payload aliases. Total reservation remains
3072; the native 2048 portion remains provisional. No packed or per-Job delta
is introduced. Delivery's separate 4096 contribution borrows the view packet,
and its concrete callback lifetime must be counted once in paired review.

The final candidate uses an explicit concrete Pool continuation and
`Inventory.commit_haul_transfer_in`. That static entry holds the original
attestation barrier through the last actual Delivery observation, direct scope
and staged-fact checks, and the entire successful cleanup. Static reclamation,
endpoint/allocator cleanup, Pool row/list/heap publication and direct result
construction follow; no successful instance override runs after the final
physical proof. Ordinary instance wrappers remain available to legacy callers.
Ten Inventory and twelve Pool extracted kernels reproduce the original state
algorithms exactly; `census.py` checks that equality against the source base.

Actual subclass probes reproduced three distinct late-callback openings: the
Pool result helper (12/555/1), Inventory reclamation/closure (15/593/2, including
one separately documented invalid pile fixture), and successful outer
commit/attestation overrides (16/603/3). These rejected attempts remain in the
evidence. The corrected source passes nine strict suites at 346 tests/4,392
assertions with every diagnostic/leak count zero. Its analyzer detected one
statically accessed field as unused; the final change is only a precise
annotation explaining that access. The final affected guard suite passes
16/603 with all diagnostics/leaks zero and analyzer 0/4. Root independently
reviewed the complete corrected static boundary, reproduced the census and
kernel equivalence, and ran the exact final guard suite again: 16/603/0,
strict/raw diagnostics and leaks zero, analyzer 0/4, all temporary inputs
restored and source unchanged. This accepts lower-owner correctness and source
census. Actual Delivery composition, native memory and runtime qualification
remain separate acceptance gates.

A final source review also added the existing Pool lot range/generation check
to the new source planner: a valid Inventory lot outside the smaller Pool
namespace refuses before the journal starts. The actual mismatched-capacity
test passes and is included in the final guard suite. Memory and public
signatures are unchanged.
