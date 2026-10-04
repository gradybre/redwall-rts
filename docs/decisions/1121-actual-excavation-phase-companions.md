# 1121 — Actual excavation phase companions

**Status:** implemented; independently reviewed component evidence accepted. 2026-10-04.

The actual Sites transaction must retain one original phase tuple through the
last Inventory observer and publish all prepared geometry after payment without
another observer. Decisions1117 and1120 provide the guarded START and terminal
settlement calls; this decision connects the actual spatial owners to them.

## Owned boundary

Geometry owns SpaceAuthority, SpaceOwner, Placements, Locations, Routes and
WorldRoutes plus their tests and this record. Root owns the new non-flat
EntryStructure adapter (1122), base WorldBindings and the shared payment owners.
Construction owns EntryWorldBindings (1119), Contacts and the first-prefix test.
No source from those other leases is changed here.

One once-bound `Locations.PhaseContext` holds exact weak actual Authority,
Placement, Sites, Space and Locations identities and the original strong Budget.
It pins World, Placement, Site, Room, Project, operation, stage, original cold
token, Space/Locations/Routes tokens and geometry/profile/catalog/Placement
revisions. A copied token or interface success cannot authorize a publication.

`Placements.prepare_phase_refresh` follows actual Space seal, refreshes every
retained Placement/opening source pin and existing endpoint/edge, and returns
the real sealed Locations candidate token. It creates no endpoint, edge, part,
installed prefix, paid Site, payment receipt or worker assignment. The source
and payload that existed before preparation must still be current; refresh must
not normalize stale unrelated Placements or openings.

## Ordering and lifetime

The original Authority cold operation owns the single shared lease. Full
physical/structural qualification and staging precede companion preparation.
Its old snapshot/qualification copies are dropped before the companion copies.
Locations coverage is sealed and drops its image before WorldRoutes compiles
the current certificates. No nested lease is acquired. Cleanup drops only the
exact original candidates and never releases a replacement token.

START and COMMIT/CANCEL final observers run after Inventory's observing work.
Each is followed by the same captured actual tuple and direct final source,
installed-surface, endpoint, graph and certificate checks. Terminal retries do
not demand a released worker. The postpayment tail uses static actual Sites
window checks and publishes Space, Locations, graph/certificates and Placement
source pins in that order. No external observer runs after payment.

An exact active PhaseContext publishes the sealed Space candidate even when
its region rows did not change. Owner seal already assigns base+1; that one
successful receipt updates all companion revisions and the Authority cache.
Refused payment advances nothing. Ordinary paths retain their existing no-op
behavior. This publication occurs at phase boundaries, never on a WORK tick.

## Memory and work admission

Reuse all existing inactive banks and row scratch. The context numeric payload
is128B (five full refs and eleven I64 controls) plus one Placement mode byte.
The reproducible source census gives1799/2048 fixed logical bytes, including
the context once and the existing shared128-byte Order/Assembly caller pair.
Owner retains only a weak context link; Locations borrows the same packet.
No additional reserve or per-row column is added. Weak/strong reference headers
and native capacity remain unmeasured.

The longest new cross-owner numeric chain is484/512: Authority's three active
frames108, provider callback40, Placement preparation64, and the installed
Location refresh chain272. Terminal installed attestation is360/512. The
existing helper allowance is included in1799, not charged again. Source/claim
and retained-row scans are precharged against the finite actual Domain check
allowance; endpoint and edge iteration also spend their existing operation
counters before entering each scan.

Using the accepted1093 two-Plan maximum145872 and a conservative4096 control
allowance, sequential cold peaks are691024 for Locations and526800 for
WorldRoutes, both inside the original1048960 lease. These values include the
full old/new plan overlap while the binding callback executes. The original
survey has already dropped; Location coverage drops before graph compilation.
Preallocated Placement/endpoint/graph banks are already reserved, with no second
charge or cold duplicate. The exact calculation and function paths are in
`docs/validation/evidence/underground-phase-companions-2026-10-04/census.json`.

## Concrete dispatch contract

`bind_phase_authority(actual_authority)` binds the actual reciprocal Sites,
Space and Locations once at quiescence. `prepare_phase_refresh(authority,
placement, site, operation, stage, room, space_token, cold_token)` follows
actual Space seal and returns the real Location companion token. A zero result
refuses and drops only its own candidates. `phase_context(token)` lends the
typed packet only after all Location/graph/certificate candidates are sealed.
Consumers must compare the entire original tuple, not accept the token alone.

The static early `phase_operation_leaf_refusal(placements, authority, site,
operation, stage, room, project, cold_token, space_token)` is for actual
Structure PREPARED identity checks, including the busy preparation interval.
It does not claim complete companions or physical qualification. Root1122
must use it whenever phase mode is active, not infer quiescence from a false
busy flag. `phase_context_leaf_refusal` attests complete prepared identity;
`phase_refresh_refusal` runs observing proofs; `prepared_phase_leaf_refusal`
closes all pure source/claim, old-payload and installed-surface facts.

Authority implements1117 `final_start_observation_refusal` and
`final_start_leaf_refusal`, plus1120 `final_settlement_observation_refusal` and
`final_settlement_leaf_refusal`. Bindings supply the exact Site/op/stage/cold/
Space/companion pair `phase_final_observation_refusal` and
`phase_final_leaf_refusal`; their bases refuse. The latter callback is followed
by Authority's concrete actual companion leaf, so an interface that returns
success after discarding its original candidate cannot authorize payment.

The actual Sites postpayment window enters `commit_phase_preflighted` directly.
Generic Owner publication stays blocked while actual Authority retains the
original Space token, including the interval after Placement companions have
been discarded. Independent review found that clearing only issuer/context
controls had reopened generic publication before payment. Both real generic
and static publication attacks were reproduced, then corrected by checking
the actual Construction→Sites→Authority token independently through abort or
successful publication. No new receipt, state field or permission flag was
introduced by this correction.

## Required evidence

Actual paid START/COMMIT/CANCEL, unchanged-row publication, worker-free terminal
retry, exact old endpoint/path payloads,
source drift, lease release/replacement, wrong Site/Project/stage/issuer,
observer reentry and hostile generic publication must be exercised. Refusal
must preserve physical state, Inventory/WIP, all live banks and original or
replacement leases as appropriate. Strict isolated-user suites, analyzer and
independent source review precede commitment. Non-flat Structure, first-prefix
composition, production profiles, stair motion and native/performance gates are
separate and are not claimed by this component.

The local fixture deliberately uses synthetic physical/contact/structure
content while retaining real Sites, Work, Funding, Inventory and all companion
owners. Installed fractional-floor source/restore regressions run separately
in1114's actual paid installation suite. A positive1121 refresh of that endpoint
after L0 and before T0 remains an explicit1119 first-prefix composition gate;
separate passing suites do not close it.

The final clean eleven-suite run passed409 tests/32011 assertions, zero
failures, every strict/raw unexpected diagnostic and exit leak count zero.
Analyzer found zero warnings in ten pinned files. Construction independently
accepted all ten unchanged final pins after the reproduced publication escape
was corrected. Source, temporary project settings and parked assets were
verified unchanged/restored. The ordinary structural suites passed19/240 and
6/64; the actual phase fixture passed13/234. The older EntryBindings fixture
now explicitly checks its real Room generation in its synthetic final leaves,
instead of inheriting the isolated economy fixture's generation1 assumption.
All rejected runs and the positive/rejected publication witnesses are retained
under the1121 evidence directory.
