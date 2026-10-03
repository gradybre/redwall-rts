# 1056 — Physical excavation owns paid phase projects

Date: 2026-10-02 · Status: Increments A/B1/B2 implemented; concrete physical-site/worker integration in progress

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

## Increment B1: atomic reservation-owned input consumption

`Reservations.consume_job_inputs` consumes the exact selected purpose's actual lot claims,
with generation and absolute-tick expiry checks, while reserving output container mass in the
same Inventory transaction. The reservation rows retire only after that transaction commits.
The new `PURPOSE_EXCAVATION_INPUT = 3` appends to the existing explicitly numbered purpose
domain; existing purpose numbers, packed columns and save records do not change. The caller
must prove the actual phase bill, delivered location and Job liveness before using this
recipe-agnostic primitive. It admits no arbitrary quantity argument and has no per-input-lot
cap: fragmentation reaches the existing global reservation/Inventory capacities, which refuse
atomically. It also handles material-free work that still needs a real output reservation.

## Increment B2: real WIP and first-pile output ownership

`excavation_inventory.gd` holds only consumed phase inputs: generation-qualified
Construction ownership, exact per-input-lot metadata receipts, and real reserved Inventory
output mass. Loose quantities remain in Inventory. The explicit receipt budget is a finite
world engineering budget; there is no fixed per-phase fragmentation cap. Exhaustion refuses
before payment. Canonical per-item rounding carry returns exactly floor(80% of the whole
phase input), even across 500 single-milli receipts, without erasing source quality,
provenance, recipe or the age observed at consumption. Claimed inputs aging between delivery
and work start keep that later age. Failed refund publication retains all WIP and loss accounts.
Material-free cancellation has no refund-capacity requirement; it still releases its actual
output reservation and retires an owned empty pending pile where applicable.

An empty ordinary finite World-owned material container is permitted at a space-owner-held
output contact. It has exactly ground-pile capacity, filter, anchor and ownership shape but
is not yet in the ground-pile map. A cut reserves real mass there before productive work.
At completion, one Inventory transaction releases only that reservation, creates actual earth,
and `promote_to_ground_pile` turns the **same nonempty row** into a pile. The existing ban on
committing an empty claimed ground pile is unchanged. Promotion revalidates the actual pile
spatial authority, journals both container and tile map, and requires an explicit transaction;
an invalid size, occupied contact or later output failure rolls back all of them. Cancelling
before any output releases the reservation and destroys the still-empty staging row.

Actual phase output publication also lives in this helper: one fresh/reclaimed earth output,
or the paired wood/stone support salvage. A refusal while creating the second salvage lot
rolls back the first, the mass release and all WIP publication. Another phase reserving the
same container keeps its own mass claim. Successful output clears funding exactly once;
work-ready retries and duplicate calls cannot create a second output.

The generic Construction delivery, work, cancellation, material-container and retirement
mutators now consult the bound typed authority's synchronous action permit for excavation.
Passing the authority object's identity alone is insufficient to retire a phase. The concrete
Sites owner opens these permits only around its own fully preflighted transaction. Unit
fixtures explicitly label their synthetic authority permission; they supply no runtime
geometry or worker admission. Legacy building/furniture accounting remains on its existing
path. The abstract spatial/domain and Work publication interfaces are declared here to keep
the next owner composition typed and fail closed, without activating them in a demo.

The independent review found and corrected an unnecessary reachable-refund-container check
for zero-input phases, and added direct helper output tests rather than relying on a manually
recreated Inventory sequence. Both findings were independently rechecked as resolved.

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

Increment B1: the new real Inventory/Reservations tests report
`7 test(s), 2472 assertion(s), 0 failure(s)`, including an aborted consumption of 1200
fragmented input claims at the Inventory journal limit. Existing reservation, carry and column
suites report respectively 38/400, 10/66 and 22/1384 tests/assertions: combined with the new
suite, **77 tests, 4322 assertions, 0 failures**. Every diagnostic/log footer is the exact zero
footer above. Evidence: `/tmp/ug-excavation-reservations/` and `/tmp/ug-excavation-reservations-final/`. The two changed GDScript files
report `0 GDScript warning(s) in 0 of 2 file(s)` on LSP port 6146.

The independent B1 review also requested two owner-composition regressions: another Job's
claim on the same lot survives consumption, and Inventory's commit-time
`GROUND_PILE_EMPTY_WITH_CLAIM` refusal restores the complete Inventory and pool states. Both
pass. First-cut output staging/promotion is a following owner transaction, not a relaxation of
the existing prohibition on committing a lotless ground pile.


Increment B2: strict primitive owner tests report
`24 test(s), 3783 assertion(s), 0 failure(s)`. With the focused Construction excavation,
existing ground-pile and Inventory suites, the exercised boundary comprises **206 tests,
5143 assertions, 0 failures**. All diagnostic and raw-log footers have zero unexpected
errors/warnings, zero expected/tolerated diagnostics and zero object/resource leaks.
Evidence: `/tmp/ug-excavation-b2-current/` and
`/tmp/ug-excavation-b2-reviewed/test_excavation_sites.log`.
The analyzer reports `0 GDScript warning(s) in 0 of 6 file(s)` on dedicated LSP port 6146.
This verifies Inventory/WIP owner composition; concrete Sites/Work, live geometry and
production persistence are not asserted by these synthetic spatial fixtures.
