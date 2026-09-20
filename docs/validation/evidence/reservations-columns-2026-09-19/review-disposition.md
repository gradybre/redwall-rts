# Independent source review disposition

The reviewer found no implementation correctness defect. Astra resolves its
acceptance gaps and scoped findings as follows; exact-head CI remains required.

F1: added executable foreign-Inventory negative control while the actual
Inventory is in a transaction. It demonstrates the documented caller boundary:
the adapter checks the supplied object, not world identity. The same test shows
post-load audit fails against the foreign Inventory. Actual open/poisoned flags
still refuse when the actual Inventory is passed. SAVE-ORCHESTRATOR now names
world association and every-lot reconciliation explicitly.
F2: documented the37R constructor body in the adapter apply docstring. Keep the
accepted record constructor API; do not introduce an unreviewed empty-record
shortcut. allocation-phases.md already includes both discarded constructor
bodies and now adds conservative complete-call packed-buffer envelopes.
F3: explicitly sequence the arithmetic repair before enabling external-file
loading. PLAN-RESERVATION-TOTALS is active planning with an independent contract
review; no file loader is activated here and no admitted rows are narrowed.
F4: publish conservative234R+8J+8L capture and196R+8J+8L apply allocation
envelopes, with exact maxima and assumptions. The review's160R estimate mixes
nonoverlapping phases and omits the later staged block constructor. No exact
peak/RSS or universal retained-snapshot claim is made.

Required gaps:
1. Added every live canonical/derived array shape, both head extents, native
   owner R0/R32769 and J/L0 tests. Both capture and restore refuse safely.
2. Added in-range wrong active/free counts that sum toR but disagree with rows;
   capture refuses and restore recomputes correct counts.
3. Added capture/apply/recapture equality for every encoded field plus framing
   metadata and public claim image. Existing literal block goldens remain.
4. Added aliased slot/generation input arrays on restore, then proves owner
   columns are independent of each other and the caller.
5. Registry prose correction is in docs/persistence_state_registry.md: positive
   occupied quantity, semantic sorted chains, column diagnostic and adapter.
6. Full local4747/186266/0 and15static logs are archived; final expanded focus
   is122/2944/0. Negative controls and exact-head CI are required before merge.

A real invalid reserve operation inside an open Inventory transaction now
exercises poison semantics; private poison-only injection remains a useful
precedence/read test. The single-block hashes are explicitly literal wrapper
plus public column-slice probes, not a claim to exercise the full encoder.
Existing test_save_section_inventories is included in every focus run.

The review's claim that five owners still publish nothing is stale. Inventory
and StockAge are already integrated, and this packet adds Reservations. Gear,
fishing, forage and whole-section assembly remain open. See the sibling
../reservations-columns-contract-2026-09-19/ directory for contract/probe evidence.
