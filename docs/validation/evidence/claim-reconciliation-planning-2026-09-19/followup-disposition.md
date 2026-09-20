# Astra source and runtime disposition of the follow-up review

The second independent report was accepted as review evidence, not as factual
proof of its alleged defects. All input hashes matched and the worker stopped.
Astra read the missing complete call paths and ran seven public lifecycle tests:
7 tests /95 assertions /0 failures in public-lifecycle.log.

X-1 REFUTED: claim_forage obtains `row = Directory.get_typed_row(job_ref)` immediately
before _write_claim. Claim row IS Job typed row. The public fixture deliberately
makes Directory slot differ from typed row and preserves distinctive tick1234
and the exact PID. No timestamp repair is justified; live provenance equality
remains a valid rule. The stale docstring about rebuilding keys is historical
comment debt, not executable mis-indexing.

X-2 REFUTED: _release_claims_of_zone_slot matches the complete zone reference as
EITHER basin OR designation before release. destroy_zone invokes it before
removing patches, clearing totals or destroying Directory identity. Public basin
deletion clears another designation's claim and debits its total; designation
deletion retains previously collected basin usage. A defensive missing-zone
branch in legacy cleanup does not demonstrate a healthy producer of that state.

X-3 REFUTED for an active claimed basin: claim admission requires the particular
patch to exist; set_basin refuses an owner with any patches. The only patch removal
helper is private and called by destroy_zone, which first releases all referencing
claims. Public rebind of a designation releases its existing claim; public rebind
of its claimed basin refuses and subsequent collection still succeeds. A chain
among patch-free unclaimed zones is not a counterexample about active claims.

X-4 narrowed: all five patches are NOT required. Public create_patch admits one
kind independently; the fixture claims only kind0 with exactly one patch present.
A checker may require the particular claim's patch, never a complete five-set.
create_patch_set preflights each row; no speculative partial-write defect accepted.

C-2/C-3 confirmed by public witnesses: cancelled Job and post-admission membership
can retain the claim. The normal cancelled sweep releases exactly once. Membership
is not a load refusal; saved order keys stay exact. Destroy-before-purge remains
covered by the merged exact-slice tests. Wrong live typed-row association is a
separate malformed input case; stale original refs must not be reattributed.

The report's basin-only wording in A-1(c) is incomplete: sum into BOTH distinct
resolved designation and basin rows, count one when equal, then compare every
saved zone total, including rows with zero claims. No quota-time or all-patches
invariant is invented.

No new runtime defect established by this review. No additional remediation lane
is warranted. Remaining work is the exact pure-checker input contract and binding
its immutable projections to the future section4/file coordinator; this evidence
does not claim that those codecs, captures, or activation interfaces already exist.
