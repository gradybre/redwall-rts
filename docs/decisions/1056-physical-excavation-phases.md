# 1056 — Physical excavation owns paid phase projects

Date: 2026-10-02 · Status: Paid-cut physical owner independently reviewed and accepted; production geometry/runtime/save and performance qualification remain queued

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

## Increments B3/C: physical sites and productive workers

`excavation_sites.gd` is the sole physical quantum history owner. It binds actual shared
Construction/Jobs/Work owners and validates a real World directory generation. The typed
spatial adapter supplies the whole world datum, minimum quantum and extent; Sites copies
those values once. A picked world origin must lie exactly on the 1024u lattice and within
that extent. It is never rounded or reinterpreted using a tool-local or room-local datum.
A new room claim, cancelled project or safely retired room reuses the original permanent
physical key, including retained work, installed support, embedded earth and virgin-source
history. History rows never evict or recycle into another quantum.

Storage is sparse packed records rather than dense 3D world cells. The caller supplies an
explicit finite record budget; an in-bounds key that cannot fit refuses before any project
payment. A binary sorted index maps absolute lattice ranks to permanent record rows; cold
insertion is O(n), while bound productive work uses direct generation-validated references.
This technical capacity is not a number-of-rooms or underground-depth rule. Geometry and the
actual world memory profile remain separate qualification work.

A paid operation is a real BUILD Job, not a timed event. Its requester must name the current
Construction generation, its remaining work must agree with Construction, and it cannot be
a coordinator/member or use an unset tool requirement. Actual Job assignment, equipped
Gear ownership, the Gear Job claim and Work's matching claim must all agree. Each face has
one registered worker and each room project has at most four. CHILD excavation is refused
unconditionally under HAZ-001. Other species/life-stage profile and contact qualification
must come from the real spatial/movement adapter; no adult fallback is provided here.

`record_deliveries` derives delivery deltas from the actual reservation rows and bound
material container. `begin_phase_work` consumes those claims into WIP and reserves finite
output before enabling actual Work. Productive Work now checks the live tool gate: missing
required equipment is no longer implicitly bare-hand work. It also asks Sites to validate
funding, pause, current support/contact/output proof, worker generation and progress agreement
before changing WU, XP or durability. After the real Work transaction, a synchronous Work-owned
publication window lets Sites read the actual accepted Job delta. A manually altered Job
counter followed by a public callback cannot impersonate that window.

Physical transitions implement brace/cut/finish and the coupled safe-backfill/support-salvage
operation, including the never-opened solid exception. Material-free cut and finish
cancellation refund no goods and require no invented refund container. Started material
phases return the adopted amount, keep physical earned work and require full inputs again.
That applies even when retained work is already ready: no new tick is needed, but new inputs
are. Output-blocked completion retains WIP and WORK_DONE. A released worker is not required
to spend another tick to retry the same ready output. Recutting paid backfill withdraws its
embedded earth and emits BACKFILL_RECLAIM, never another virgin source.

Earth has the cold identity initial+virgin = Inventory+WIP+embedded+cancellation loss for the
currently composed owner set. Wood and stone separately account consumed brace funding,
current WIP, committed returns, cancellation loss, installed support, committed salvage and
the unrecoverable half of removed support. These identities do not confuse Inventory's generic
recipe source/sink audit with new geology. The future spoil-tip owner must participate in the
global earth identity; this implementation does not claim tip preparation/compaction/reclaim.

Pause reaches actual Work immediately through Construction; the Sites pause API additionally
releases the real worker/tool ownership. Resumption requires real reassignment and tool/contact
revalidation, preserving input WIP and the contributor's wear/XP carries. Unexpected external
worker detach or stale owner generations are diagnosed, not silently overwritten. Before
refund/output retirement, an event-driven scan checks all 8192 Jobs for late requester links;
no matching Job or its claims can be orphaned by closing a project.

## Allocation, load and performance envelope

The receipt request must be positive, no larger than the actual Reservations owner's
row capacity, and no larger than the existing global `Reservations.ROW_CAPACITY = 32768`.
Invalid requests refuse before any packed allocation. This bounds concurrent consumed-input
metadata, not all historical deliveries or the size of a room. Exhausted receipt capacity
refuses payment; it never truncates claims or refunds. Its canonical free-stack permutation,
free count and allocated capacity affect the next receipt allocation and must be preserved.

Sites receives a caller-selected history capacity within a separate **8388608-byte packed
arena ceiling**, including its fixed indexes and scratch and excluding separately counted
Funding. This is an engineering allocation/refusal envelope, not a production default or
an authored room/level limit. No history eviction permits another virgin-source event.
One record costs 113 packed bytes and the fixed arena costs 36880 bytes, so:
`MAX_SITE_CAPACITY = floor((8388608 - 36880) / 113) = 73909`.
That maximum allocates 8388597 bytes, 11 bytes below the ceiling. Both the original request
and the copied world domain are validated; a larger request never silently becomes a usable
smaller owner. Budgets and both Construction/Work binding preflights run before allocation
or either one-time binding, preventing a refused initializer from stranding the other owner.

For requested site capacity S and receipt capacity R, the exact packed accounting is:

| Owner and category | Bytes |
|---|---:|
| Sites authoritative columns | 101*S +4096 |
| Sites derived sorted-key and Job indexes | 12*S +32768 |
| Sites transaction scratch | 16 |
| Funding authoritative columns | 2324480 +48*R |
| Funding transaction scratch | 6144 +40*R |
| Combined actual packed backing | 2367504 +113*S +88*R |

At S=256 and R=512 this is 2441488 actual packed bytes. The diagnostic local state image measures
2415024 bytes because it excludes transaction scratch, includes derived indexes, and adds
160 bytes of Sites scalar image plus 16 bytes of Funding scalar image. Object/Variant headers,
collaborator stores and allocator overhead are not packed-byte measurements. At both allocation
maxima the combined packed backing is 13602805 bytes. The derived `_earned_capacity`
cache adds one 8-byte numeric scalar outside packed columns and is not independently saved;
it is recomputed as five operations times the admitted history capacity. This maximum is not permission to exceed
the composed world's memory budget alongside other underground owners.

No physical restore candidate or production decoder is implemented here: additional restore
staging is presently zero implemented bytes, not a claim that a future loader needs none.
UG16 must budget live plus staged columns, allocator/free-list validation, derived-index rebuild,
codec buffers and whole-world reconciliation before save activation. The local `state_bytes`
is a cold diagnostic allocation and is not the loader. Sites' domain/capacity/count, physical
history and conservation scalars remain required even with no active paid phase. Its sorted
key and Job indexes can rebuild; registered worker generations are authoritative. Funding
requires all project/output references, receipt chain metadata, losses, capacity/free count,
and free-stack order. Synchronous permission/publication candidates and math scratch are not
future state and must be absent at capture.

The initial measured paid Work batch for 256 actual working residents was 13878 microseconds
mean; the same real resident/Job/equipped-tool fixture without excavation was 2364 microseconds.
Both paths use required general tools and actual WU, XP and wear carries. Assertions are outside
the measured interval. Attribution identified four repeated Gear `_resolve_row` scans inside
the original worker gate: its 256-worker cost was about 6596 microseconds. The combined
`Gear.equipped_work_claim_refusal` reads the same full lot, owner and Job generations, equipped
flag and positive durability after one row resolution, adding no persistent state or raw handle.
It preserves Sites' existing stale-claim versus broken-tool refusal mapping.

With that change the instrumented 256-worker batch measured 10378 microseconds mean
(maximum 10478), versus 2366 microseconds mean for the same equipped-tool Work baseline.
The separately measured worker gate fell to 2576 microseconds; bound owner/identity checks
were 1275, synthetic space qualification 310, zero-output brace checks 88, and the complete
productive preflight 3039 microseconds. Actual Work-stage attribution measured 6505
microseconds in excavation preflight, 1202 in paid progress publication and 504 in Work's
accepted-work commit; these figures are diagnostic, not additive independent proofs of the
total. Synthetic geometry callbacks contain only constant-time scalar/range checks.

This still exceeds the **2 ms whole-tick target**, before real 3D qualification. No performance
closure is claimed. The bound spatial owner must supply safe revision-bound qualification
without per-tick geometry allocation, and further profiling/index qualification remains
required. A Gear reverse index is explicitly outside this increment and needs its own memory
ledger/decision. Cold cancellation scans the full 8192-Job domain; its roughly 3.9 ms cost is
an event-driven lifecycle operation, never a per-frame UI query or an unbudgeted 256-project
completion burst.

## Actual world-owner wiring

Numerically identical EntityRefs and lot references in separate worlds do not prove shared
ownership. Sites now preflights the actual Construction/Jobs/Work directory relation, Gear's
Inventory/Directory/Residents binding, the catalog's last successful Inventory registration,
and Reservations' Inventory binding before allocating paid state or binding any owner. The
same constant-time composition checks run again on every bound phase mutation and productive
work tick, so later generic Work/Gear or catalog rewiring cannot redirect excavation.

ItemDefinitions retains a weak reference to its last successfully registered Inventory. Failed
loads, including a null target, preserve that reference; a later explicit successful registration
into another Inventory remains supported and causes an existing Sites composition to refuse.
This is derived world wiring, not a new catalog value or serialized pointer.

Reservations records its exact Inventory after a successful first claim, actual committed
Inventory operation, explicit empty-pool composition, or Inventory-aware column restore.
Failed claims/imports publish no binding. Every later Inventory-taking claim, consumption,
release, carry or import checks the exact owner before mutation, even when foreign numeric refs
and reserved totals coincide. Emptying a pool or calling its teardown `clear()` preserves the
binding; another world needs a new pool. An expired weak owner refuses reuse.

The optional Inventory argument to `restore_reservation_columns` preserves existing pure-column
fixtures. Omission retains existing wiring; an unbound nonempty import cannot compose with
Sites. Explicit restore may repair malformed old payload but cannot change an already-bound
world. The production save adapter passes its actual Inventory into that owner restore. UG16
must reconstruct and validate these owner bindings after loading; pointer addresses are not
hashed or serialized, and binding alone does not prove whole-world reconciliation.

## Spatial publication and remaining integration gates

The adapter's ADMIT and WORK stages only validate. START, COMMIT and CANCEL may prepare a
bounded candidate tied to the exact operation, room/quantum identities and current revision.
Only after actual payment/output/refund succeeds does Sites call the synchronous non-failing
publication hook. Any refusal after preparation calls `discard_transition`, releasing only
operation scratch and preserving lasting phase/contact/output leases. Retried settlement
revalidates and prepares again. No productive tick prepares topology, and an economic cube
never grants navigation by itself. The adapter must reserve all necessary destination storage
and topology capacity before attesting that publication cannot fail.

Real dry substrate, support, occupied volumes, legal work contact, output adjacency and safe
closure routes require UG08/UG21's concrete owner plus UG09's actual world adapter. These
synthetic spatial fixtures are never installed in the demo. Room revision handshake wiring
still must release the permitted actual phase claims and register all child Construction Jobs;
the existing same-value direct pause-writer limitation is not erased by the Work gate.
Production movement/profile, geometry, runtime dispatch and versioned save composition remain
queued gates. After all phase projects retire, Sites still holds future-affecting physical
history, so its explicit legacy-save refusal must remain wired until UG16 supplies its codec.
The local state image is test evidence, not a production save/restore format.

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


Increment C final frozen source: after moving demo assets aside if present, deleting the local
`godot/.godot` cache and running `godot --headless --path godot --editor --quit`, the focused
strict shell runner reports **417 tests, 52821 assertions, 0 failures** across 14 suites.
The concrete physical suite is `34 test(s), 22295 assertion(s), 0 failure(s)`; the consumed-WIP
suite is `25 test(s), 3804 assertion(s), 0 failure(s)`. Existing Construction, paid ledger,
Work, Gear, catalog, Reservations, carry, column restore, save-owner and demolition-completion
regressions are included. Every shard reports:

```
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Evidence is in `/tmp/ug-excavation-final-clean/`; the clean import log contains zero
error/warning lines. Final clean-run instrumentation measured 10336 microseconds mean and
10696 maximum for 256 paid workers, compared with 2386 mean and 2588 maximum for 256 actual
equipped-tool workers without Sites. Packed reflection measures Sites 65808 bytes plus Funding
2375680 bytes, totaling exactly 2441488 bytes at S=256/R=512. The parent integration owns the
full no-argument suite and canonical/whole-world budget qualification; these focused results
are not substituted for those gates.
The final frozen-source analyzer reports `0 GDScript warning(s) in 0 of 14 file(s)` on
isolated LSP port 6146 (`/tmp/ug-excavation-final-frozen-analyzer.log`). The strict Markdown
state registry reports `PASS -- 96 modules, 465 rows, 808 packed columns checked`.

The final independent review accepted the frozen 14-file source boundary without a remaining
blocker. Repository-retained raw logs, source hashes, review scope and the exact focused
summary are under [UG06 evidence](../validation/evidence/underground-ug06-physical-2026-10-03/README.md).
