# 0185 — Bind travel admission to qualified route clearance

September20, accepted for bounded implementation by Astra under the approved settlement outcome.

Movement exposes an explicit refusal for unqualified production body clearances but did not consult it when admitting a ready route. A caller-supplied route class could therefore bypass that boundary. The independently reviewed ground-access audit confirmed this source fact after correcting unrelated geometry and persistence claims.

Apply GROUND-CLEARANCE-R01v1: a read-only ready-route clearance getter and an admission check requiring the actual profile qualification result and exact class equality before any attachment. Preserve current production qualification refusals. Keep reference-motion fixtures explicit under godot/test with a synthetic override of the existing profile reader; never add a production bypass or assign body dimensions to make tests pass.

No packed memory, save schema or route-graph meaning changes. Existing traveller state remains intact on failed re-admission. Full physical profiles, contact producers, source-bound sweeps, safe topology and release acceptance remain separate work. Required independent review and actual focus/full/static/mutation/CI gates are specified in the contract.


## Acceptance clarifications

This gate checks clearance at admission. It adds no per-tick clearance revalidation or qualified profile publication; future profile changes must use their separately specified revision/revalidation protocol. In current sequential production, the ready-route reader cannot fail between the prior is_ready check and its read: no intervening production operation changes Navigation. Its defensive ROUTE_REQUEST_NOT_READY fallback is retained, and a mutation of only that unreachable branch is equivalent under this contract rather than a missing executed witness.

Astra permits a narrow test-only exception to the 30-line style rule for the cohesive before/after re-admission and getter-phase scenarios in test_movement_clearance.gd. Keeping their ordered setup, failure and preservation assertions together aids review. Helpers remain typed and bounded; this grants no production-function or general test-style exception. Review advisories and historical patch identities are dispositioned in the evidence directory; no current Movement memory arrears are created or repaid.
