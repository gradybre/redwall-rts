# Section4 acceptance — active implementation

SAVE-S4-CODEC is incomplete. The accepted streaming contract is SAVE-S4-STREAM-R01v2 / ADR0169; its independent planning reviews, source proofs and byte fixtures are in [the evidence folder](../validation/evidence/section4-planning-2026-09-20/).

| Prerequisite | Current evidence | Remaining acceptance |
|---|---|---|
| Streaming envelope | Contract accepted; focused21tests/11814assertions passes; six required mutants and four preflight bypass mutants killed;58 generator checks and17 static gates pass | Merged PR160 after CI35491728462 passed4869/202461/0 plus generator and fault checks; structural envelope accepted |
| All18 semantic validators | Owner/API census and cross-section map; owner9 Needs primitive implemented under NEEDS-S4-VALIDATE-R01v2 / ADR0170 with exact-code tests and28killedmutants; local4884/208744/0 and two source reviews accepted; exact-head CI pending | Other17 owner packets, Needs status/departure domains and cross-owner saved consistency remain incomplete |
| Owner bindings | Bulk APIs exist for Jobs, Needs and Residents; other15 are incomplete for section4 | Atomic capture/apply contracts, complete owner columns, coupled section restoration, refusal/continuation tests |
| Final section4 integration | Explicit blocked parent task | Integrated tests against real owner APIs and every canonical field; no omitted owner or zero substitute |

The parent task cannot pass from a codec round trip alone. Full-file provenance, other section bodies, disk-backed rollback, saved Directory/claim binding, state digest and complete continuation remain their separately named prerequisites. No release flag or first-playable claim changes here.
