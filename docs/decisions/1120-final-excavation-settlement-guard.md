# 1120 — Final excavation output and refund guard

Date: 2026-10-04. Status: component independently accepted; concrete spatial
adapters and integrated gameplay verification remain pending.

Two strict regressions reproduce a missing boundary after decision1117's START
guard: an actual Inventory storage observer runs after a cut/refund lot is
created and changes the synthetic room generation while its own endpoint stays
valid. The old Sites coordinator still publishes2000milli-U of earth or returned
wood, clears WIP and retires the physical phase. The rejected run reports2tests,
33assertions,2failures and zero unexpected diagnostics or leaks. Its source pins,
commands and logs are retained in `underground-phase-settlement-2026-10-04`.

Inventory must own the final purpose5 settlement observation barrier, as it
already does for purpose5 inputs and purpose8 settlements. The Sites coordinator
retains its original COMMIT/CANCEL candidate, Project/action and spatial owner.
All final observers run while Inventory can still roll back; a pure leaf then
rechecks those exact identities, actual Job/project/receipt/physical state and
the prepared spatial/companion tokens. Nested commit/abort poisons the original
journal without closing it. Nested phase START/settlement cannot steal another
candidate. Two same-stack boolean guards add2logical bytes; no saved bank or
extra Funding account is introduced.

`SpatialAuthority.final_settlement_observation_refusal(origin, operation, stage,
room)` and the corresponding `final_settlement_leaf_refusal` are fail-closed.
Concrete Authority must delegate COMMIT/CANCEL to its existing captured phase
tuple; those adapters are a required follow-on dependency of this component.
Completed/refunding phases may have released their worker and must support a
worker-free terminal retry, without granting productive work or new motion.

An output/refund refusal preserves Inventory, claims, WIP and physical history.
As before, cancellation may already freeze the Project and release its worker;
that reversible lifecycle change is not falsely described as an all-owner
rollback. Unstarted cancellation remains a separate claim-release transaction;
this increment must not imply that it has passed the paid settlement guard.

Independent review by `/root/ug_furnishing` accepted the exact ten GDScript and
three memory-census pins, with no high or medium finding. Its low wording
correction is incorporated above. Eight strict focused suites report 278 tests,
29,639 assertions and zero failures, unexpected diagnostics or leaks; the
analyzer reports zero warnings in ten files. All 103 memory-census tests pass,
including width and missing-guard mutants. The complete command, source and
rejected/accepted evidence is retained in
`docs/validation/evidence/underground-phase-settlement-2026-10-04/`.

The actual first-prefix spatial adapters are required before this component is
integrated. The full Kitchen/underground workflow remains open.
