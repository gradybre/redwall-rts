# 1056 — Physical excavation owns paid phase projects

Date: 2026-10-02 · Status: Increment A implemented; physical transaction and worker bridges in progress

## Authority

D08, D18/D19 and D26–D28 are approved direction. SET-MOVE-ECON-001 ECON-001–006 owns
all excavation prices, work, support salvage, and virgin/backfill conservation. This record
implements those contracts; it does not authorize an economic cube as geometry clearance,
choose underground depth, supply a new material bonus, or activate production cutting.

The preparation validator `docs/validation/validate_underground_economy_hazards.py`
passed its 21 fixtures with zero failures/errors and no missing links before source changes.

## Increment A: actual Construction phase accounting

`excavation_contract.gd` separates the typed physical-site authority from Construction,
avoiding a circular preload between the concrete site owner and its accounting collaborator.
Its base authority refuses admission. The new operation domain is ASCII ordered:
BACKFILL_CLOSE, BRACE, CUT, FINISH, UNOPENED_SUPPORT_CLOSE. This is separate from the
physical phase domain and from existing BuildingState/catalog identities. Constants exactly
match the adopted numerical JSON: brace wood250/stone250 and 2000mWU; cut 4000mWU;
finish 3000mWU; coupled open-void closure earth2000 and 4250mWU; never-cut support closure
1250mWU. The physical coordinator owns actual output and salvage publication.

Construction appends a distinct live purpose for excavation. Its existing packed project
columns, generation allocator, delivery-before-work, WIP transition, pause, capped progress,
and per-phase 100%/80% cancellation accounting are reused. No phase impersonates a building
recipe. One phase has at most one builder; the following site-group coordinator must enforce
ECON's separate four-builders-per-project cap across quanta.

Opening consults a live typed site authority and reads retained work there. It does not accept
a caller's arbitrary work amount. A single physical site cannot open two simultaneous projects.
The authority is bound weakly to avoid a cycle and cannot be replaced even after its object
expires: binding a fresh ledger into the same Construction store would lose physical history.
A new world reconstructs both owners together under its save/version contract.

Physical site references belong to their own namespace. They may have identical numbers to
live Building references; opening/retiring one must never overwrite a building's construction
back-reference or appear in legacy subject lookup. The explicit site lookup filters the new
purpose. Its current bounded scan is a cold lookup, not qualification of per-tick dispatch.

`commit_completion` and `close_refund` refuse excavation with COORDINATOR_ONLY. The bound
physical coordinator alone may retire a WORK_DONE or REFUNDING site project after its
actual transaction. Work that finished before output publication remains WORK_DONE, with
no additional productive tick on retry. A cancelled material phase whose retained work is
already complete still requires its full adopted inputs before becoming work-ready again.

`material_key_at` is the key-based bill reader for new coordinators. The existing six-member
`MATERIAL_KEYS` index domain remains frozen; an earth line cannot masquerade as a legacy
index. Building/furniture bills, capacities, refunds and their existing readers are unchanged.

## Save boundary

The inherited Construction column validator deliberately keeps its frozen legacy purpose
and metadata domains. A new excavation-purpose row explicitly refuses that older codec;
it is never silently dropped or interpreted as a building type. `state_bytes` is local test
evidence, not a production save format. The future site ledger and phase owner are required
future-affecting state and need versioned registry/hash/codec composition under UG16 before
production activation. No shared save validator is relaxed for this increment.

## Following increments and integration gates

Increment B owns immutable-datum 1024u physical quantum keys, installed support, committed
virgin-source versus embedded-earth history, current phase/progress and generation-qualified
project binding. It must perform real Inventory transactions for delivered/WIP materials,
reserved local spoil output, refunds and coupled backfill/support salvage. Cancellation
preserves physical progress; restarting a project never creates a new virgin-earth source.
Increment C binds actual Jobs/Work/Gear contributions with mandatory tools and retains the
contributing resident's wear/XP remainders. No per-frame demo timer may substitute for it.

Real dry substrate, support, occupied volumes, legal work contact, output adjacency and safe
closure routes require UG08's concrete spatial authority. Synthetic owner fixtures exercise
phase accounting while that lane is built; they are explicitly not registered in the demo.
The first runtime activation remains UG09 only after those actual bindings exist.

## Validation

Increment A: seven strict shell-runner shards exercise the new phase suite and the existing
Construction, columns, paid-ledger, retired-history, demolition-completion and save-owner
suites. Combined result: **136 tests, 3045 assertions, 0 failures**. The new suite alone reports
`9 test(s), 114 assertion(s), 0 failure(s)`. Every shard reports:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Evidence is in `/tmp/ug-excavation-phase-a/shard-*.{json,log}`. The strict registry check reports
94 modules, 442 rows and 758 packed columns. Incremental editor import completes cleanly.
The zero-warning analyzer, using its own LSP port 6146 to avoid concurrent agents' editors,
reports `0 GDScript warning(s) in 0 of 3 file(s)`. The initial default-port attempt connected
to another project editor and reported the locally tested new preload missing; it is not used
as validation. Parent integration owns the final cache-deleted, asset-isolated full-suite run.
