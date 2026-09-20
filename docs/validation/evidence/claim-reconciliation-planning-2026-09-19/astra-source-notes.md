# Claim reconciliation planning — questions before a contract

Exact section7 claim owners are structurally admitted separately. They preserve
stale generations and Forage created_tick/persistent_id verbatim. Before world
activation, a NEW read-only cross-section check is required; the legacy methods
mutate saved aggregates, count/scratch or order keys and cannot serve this role.

Source shows public Jobs.destroy_job and Directory.destroy(Expedition) can leave
claims until normal stale sweeps. A finished claim snapshot is therefore not
necessarily evidence of a live owner. Need a precise save-boundary policy that
does not silently change valid continuation or reject every reachable snapshot.
Fishing owner identity stores only generation; typed-row reverse lookup after an
Expedition is destroyed/reused needs particular scrutiny. Missing habitat cases
must not pass merely because a legacy aggregate was zeroed elsewhere.

Forage public release skips missing zone refs and subtracts only present ones;
new validation must distinguish legitimate stale owner from missing ecological
state, wrong typed-row association, a live Job with mismatched created_tick/PID,
or references to unrelated live entities. Do not invent a safe policy solely
from the old rebuild method. Review architecture and accepted save contracts.

All totals must be privately checked; compare every saved habitat/zone total,
including zones with no claims and designation==basin counted once. Do not apply
normal gameplay reconcile_claims, quota cancellation, stale purges or rebuilding
as part of loading. Current quantity bounds make claim-only sums bounded, but
checked arithmetic is an explicit integration requirement, not an alleged
public overflow witness.

Section4 and5 codecs/owner records remain unimplemented. Decide whether the new
checker should consume validated decoded sections or typed owner snapshots, how
it binds all records to the same file/world and how that changes queue gates.
No production implementation authorized from these notes alone: Astra will
resolve findings into a versioned bounded contract before author dispatch.
